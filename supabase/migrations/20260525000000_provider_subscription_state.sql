-- ============================================================
-- Provider Subscription State Table
-- Tracks trial usage, paid months, and subscription status per provider.
-- Also adds is_paused to provider_services for expiration enforcement.
-- ============================================================

-- 1. Create provider_subscription_state table
CREATE TABLE IF NOT EXISTS public.provider_subscription_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL UNIQUE REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
    subscription_status TEXT NOT NULL DEFAULT 'inactive'
        CHECK (subscription_status IN ('active', 'inactive', 'trial', 'paused')),
    trial_used BOOLEAN NOT NULL DEFAULT false,
    trial_plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
    paid_months INTEGER NOT NULL DEFAULT 0,
    trial_reset_allowed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pss_provider ON public.provider_subscription_state(provider_id);
CREATE INDEX IF NOT EXISTS idx_pss_status ON public.provider_subscription_state(subscription_status);

-- 2. Add is_paused column to provider_services
ALTER TABLE public.provider_services
ADD COLUMN IF NOT EXISTS is_paused BOOLEAN NOT NULL DEFAULT false;

-- 3. RLS
ALTER TABLE public.provider_subscription_state ENABLE ROW LEVEL SECURITY;

-- Providers can read their own state
DROP POLICY IF EXISTS "pss_select_own" ON public.provider_subscription_state;
CREATE POLICY "pss_select_own" ON public.provider_subscription_state
    FOR SELECT TO authenticated
    USING (provider_id = auth.uid());

-- Edge functions / service role can manage all rows; providers can insert their own
DROP POLICY IF EXISTS "pss_insert_own" ON public.provider_subscription_state;
CREATE POLICY "pss_insert_own" ON public.provider_subscription_state
    FOR INSERT TO authenticated
    WITH CHECK (provider_id = auth.uid());

-- Allow updates via service role (Edge Function) or by the provider themselves
DROP POLICY IF EXISTS "pss_update_own" ON public.provider_subscription_state;
CREATE POLICY "pss_update_own" ON public.provider_subscription_state
    FOR UPDATE TO authenticated
    USING (provider_id = auth.uid())
    WITH CHECK (provider_id = auth.uid());

-- Admin can manage all
DROP POLICY IF EXISTS "pss_admin_all" ON public.provider_subscription_state;
CREATE POLICY "pss_admin_all" ON public.provider_subscription_state
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
