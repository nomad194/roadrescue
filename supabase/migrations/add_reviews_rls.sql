-- Add RLS policies for reviews table
-- Run this in Supabase SQL Editor

-- Enable RLS on reviews table if not already enabled
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Allow users to read reviews for jobs they're involved in
DROP POLICY IF EXISTS "reviews_read" ON public.reviews;
CREATE POLICY "reviews_read" ON public.reviews 
FOR SELECT TO authenticated 
USING (EXISTS (
    SELECT 1 FROM public.job_requests 
    WHERE job_requests.id = reviews.job_request_id 
    AND (job_requests.customer_id = auth.uid() OR job_requests.provider_id = auth.uid())
));

-- Allow users to insert their own reviews
DROP POLICY IF EXISTS "reviews_insert_own" ON public.reviews;
CREATE POLICY "reviews_insert_own" ON public.reviews 
FOR INSERT TO authenticated 
WITH CHECK (reviewer_id = auth.uid());

-- Allow public to read provider reviews (for ratings display on profiles)
DROP POLICY IF EXISTS "reviews_read_public" ON public.reviews;
CREATE POLICY "reviews_read_public" ON public.reviews 
FOR SELECT TO public 
USING (EXISTS (
    SELECT 1 FROM public.job_requests 
    WHERE job_requests.id = reviews.job_request_id
));
