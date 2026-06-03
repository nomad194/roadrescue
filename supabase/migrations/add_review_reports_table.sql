-- Create review_reports table for providers to report customer reviews
-- Run this in Supabase SQL Editor

-- Create the review_reports table
CREATE TABLE IF NOT EXISTS public.review_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    admin_response TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_review_reports_provider ON public.review_reports(provider_id);
CREATE INDEX IF NOT EXISTS idx_review_reports_review ON public.review_reports(review_id);
CREATE INDEX IF NOT EXISTS idx_review_reports_status ON public.review_reports(status);

-- Enable RLS
ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Providers can insert their own reports
CREATE POLICY "review_reports_insert_own" ON public.review_reports
FOR INSERT TO authenticated
WITH CHECK (provider_id = auth.uid());

-- Policy: Providers can view their own reports
CREATE POLICY "review_reports_select_own" ON public.review_reports
FOR SELECT TO authenticated
USING (provider_id = auth.uid());

-- Policy: Only admins can update/delete reports
CREATE POLICY "review_reports_admin_only" ON public.review_reports
FOR ALL TO authenticated
USING (EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'admin'
));

-- Grant permissions
GRANT SELECT, INSERT ON public.review_reports TO authenticated;
GRANT ALL ON public.review_reports TO service_role;

-- Function to get support email from app_settings
CREATE OR REPLACE FUNCTION public.get_support_email()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    support_email TEXT;
BEGIN
    SELECT setting_value INTO support_email
    FROM public.app_settings
    WHERE setting_key = 'support_email'
    LIMIT 1;
    
    RETURN support_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_support_email() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_support_email() TO service_role;
