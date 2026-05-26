-- ============================================================
-- Provider Required Documents Management
-- Enum status, tables, indexes, RLS, triggers (auto-verify, audit, notification)
-- ============================================================

-- ─── 1. ENUM ─────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE public.document_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─── 2. TABLES ───────────────────────────────────────────────

-- Admin-defined document types that providers must upload
CREATE TABLE IF NOT EXISTS public.required_document_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    name_translations JSONB DEFAULT '{}'::jsonb,
    instructions TEXT DEFAULT '',
    instructions_translations JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Provider uploaded documents
CREATE TABLE IF NOT EXISTS public.provider_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    document_type_id INTEGER NOT NULL REFERENCES public.required_document_types(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    status public.document_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    uploaded_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    UNIQUE(provider_id, document_type_id)
);

-- Audit trail for document status changes
CREATE TABLE IF NOT EXISTS public.provider_document_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES public.provider_documents(id) ON DELETE CASCADE,
    old_status public.document_status,
    new_status public.document_status NOT NULL,
    changed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    reason TEXT,
    changed_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 3. INDEXES ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_provider_documents_provider ON public.provider_documents(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_documents_type ON public.provider_documents(document_type_id);
CREATE INDEX IF NOT EXISTS idx_provider_documents_status ON public.provider_documents(status);
CREATE INDEX IF NOT EXISTS idx_provider_document_audit_doc ON public.provider_document_audit(document_id);

-- ─── 4. STORAGE BUCKET ───────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('provider-documents', 'provider-documents', false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: providers can upload to their own folder
CREATE POLICY "Providers upload own docs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'provider-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Providers read own docs"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'provider-documents'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    )
);

CREATE POLICY "Admins read all docs"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'provider-documents'
    AND EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ─── 5. RLS ──────────────────────────────────────────────────
ALTER TABLE public.required_document_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read doc types" ON public.required_document_types
    FOR SELECT USING (true);
CREATE POLICY "Admins manage doc types" ON public.required_document_types
    FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    );

ALTER TABLE public.provider_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Providers read own documents" ON public.provider_documents
    FOR SELECT USING (provider_id = auth.uid() OR EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "Providers insert own documents" ON public.provider_documents
    FOR INSERT WITH CHECK (provider_id = auth.uid());
CREATE POLICY "Providers update own documents" ON public.provider_documents
    FOR UPDATE USING (provider_id = auth.uid() OR EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

ALTER TABLE public.provider_document_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own audit or admin" ON public.provider_document_audit
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.provider_documents pd
            WHERE pd.id = document_id AND (pd.provider_id = auth.uid())
        )
        OR EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    );
CREATE POLICY "Admins insert audit" ON public.provider_document_audit
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
        OR changed_by = auth.uid()
    );

-- ─── 6. FUNCTIONS & TRIGGERS ─────────────────────────────────

-- Auto-verify provider when all required documents are approved
CREATE OR REPLACE FUNCTION public.check_provider_documents_complete()
RETURNS TRIGGER AS $$
DECLARE
    v_required_count INTEGER;
    v_approved_count INTEGER;
BEGIN
    -- Only proceed if the new status is 'approved'
    IF NEW.status != 'approved' THEN
        RETURN NEW;
    END IF;

    -- Count active required document types
    SELECT COUNT(*) INTO v_required_count
    FROM public.required_document_types
    WHERE is_active = true;

    -- Count approved documents for this provider
    SELECT COUNT(*) INTO v_approved_count
    FROM public.provider_documents
    WHERE provider_id = NEW.provider_id
      AND status = 'approved'
      AND document_type_id IN (
          SELECT id FROM public.required_document_types WHERE is_active = true
      );

    -- If all documents approved, verify the provider
    IF v_approved_count >= v_required_count AND v_required_count > 0 THEN
        UPDATE public.user_profiles
        SET is_verified = true, updated_at = now()
        WHERE id = NEW.provider_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_check_provider_docs_complete ON public.provider_documents;
CREATE TRIGGER trg_check_provider_docs_complete
    AFTER UPDATE ON public.provider_documents
    FOR EACH ROW
    WHEN (NEW.status = 'approved')
    EXECUTE FUNCTION public.check_provider_documents_complete();

-- Audit trigger: log status changes
CREATE OR REPLACE FUNCTION public.log_document_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- On INSERT, log the initial upload
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.provider_document_audit (document_id, old_status, new_status, changed_by)
        VALUES (NEW.id, NULL, NEW.status, NEW.provider_id);
        RETURN NEW;
    END IF;

    -- On UPDATE, only log if status actually changed
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.provider_document_audit (document_id, old_status, new_status, changed_by, reason)
        VALUES (NEW.id, OLD.status, NEW.status, COALESCE(NEW.reviewed_by, NEW.provider_id), NEW.rejection_reason);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_log_document_status ON public.provider_documents;
CREATE TRIGGER trg_log_document_status
    AFTER INSERT OR UPDATE ON public.provider_documents
    FOR EACH ROW
    EXECUTE FUNCTION public.log_document_status_change();

-- Notification trigger: insert in-app notification on approval/rejection
CREATE OR REPLACE FUNCTION public.notify_document_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'approved' THEN
            INSERT INTO public.notifications (user_id, type, title, message, related_entity_id, status)
            VALUES (
                NEW.provider_id,
                'system',
                'Document Approved',
                'Your document has been approved.',
                NEW.id,
                'pending'
            );
        ELSIF NEW.status = 'rejected' THEN
            INSERT INTO public.notifications (user_id, type, title, message, related_entity_id, status)
            VALUES (
                NEW.provider_id,
                'system',
                'Document Rejected',
                COALESCE('Your document was rejected: ' || NEW.rejection_reason, 'Your document was rejected. Please re-upload.'),
                NEW.id,
                'pending'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_document_status ON public.provider_documents;
CREATE TRIGGER trg_notify_document_status
    AFTER UPDATE ON public.provider_documents
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_document_status_change();

-- ─── 7. GRANT PERMISSIONS ────────────────────────────────────
GRANT ALL ON public.required_document_types TO authenticated, service_role;
GRANT ALL ON public.provider_documents TO authenticated, service_role;
GRANT ALL ON public.provider_document_audit TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.required_document_types_id_seq TO authenticated, service_role;
