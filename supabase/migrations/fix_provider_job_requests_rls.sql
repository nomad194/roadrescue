-- Fix provider job requests RLS policy
-- The column is job_status, not status
-- Run this in Supabase SQL Editor

DROP POLICY IF EXISTS "job_requests_provider" ON public.job_requests;
CREATE POLICY "job_requests_provider" ON public.job_requests 
FOR SELECT TO authenticated 
USING (provider_id = auth.uid() OR (job_status = 'pending' AND provider_id IS NULL));
