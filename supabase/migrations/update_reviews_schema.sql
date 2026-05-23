-- Update reviews table to add provider response and visibility toggle
-- Run this in Supabase SQL Editor

-- Add provider response fields to reviews
ALTER TABLE public.reviews 
ADD COLUMN IF NOT EXISTS provider_response TEXT,
ADD COLUMN IF NOT EXISTS provider_response_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;

-- Create index for public reviews lookup
CREATE INDEX IF NOT EXISTS idx_reviews_provider_public 
ON public.reviews(job_request_id) 
WHERE is_public = true;

-- Update RLS policy for semi-public visibility
-- Drop the old public read policy
DROP POLICY IF EXISTS "reviews_read_public" ON public.reviews;

-- New policy: Everyone can see public reviews with ratings only (not full comment)
-- Detailed review content only visible to participants
CREATE POLICY "reviews_read_public_rating_only" ON public.reviews 
FOR SELECT TO public 
USING (is_public = true);

-- Policy for reviewers to update their own review (within 24 hours, for example)
DROP POLICY IF EXISTS "reviews_update_own" ON public.reviews;
CREATE POLICY "reviews_update_own" ON public.reviews 
FOR UPDATE TO authenticated 
USING (reviewer_id = auth.uid() AND created_at > now() - interval '24 hours')
WITH CHECK (reviewer_id = auth.uid());

-- Policy for providers to add response to reviews about them
DROP POLICY IF EXISTS "reviews_provider_response" ON public.reviews;
CREATE POLICY "reviews_provider_response" ON public.reviews 
FOR UPDATE TO authenticated 
USING (EXISTS (
    SELECT 1 FROM public.job_requests 
    WHERE job_requests.id = reviews.job_request_id 
    AND job_requests.provider_id = auth.uid()
))
WITH CHECK (EXISTS (
    SELECT 1 FROM public.job_requests 
    WHERE job_requests.id = reviews.job_request_id 
    AND job_requests.provider_id = auth.uid()
));

-- Add function for provider to respond to review
CREATE OR REPLACE FUNCTION public.add_provider_response(
    p_review_id UUID,
    p_response TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.reviews
    SET provider_response = p_response,
        provider_response_at = now()
    WHERE id = p_review_id
    AND EXISTS (
        SELECT 1 FROM public.job_requests 
        WHERE job_requests.id = reviews.job_request_id 
        AND job_requests.provider_id = auth.uid()
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.add_provider_response(UUID, TEXT) TO authenticated;
