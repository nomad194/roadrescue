-- Add function to calculate provider average rating
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.get_provider_rating(p_provider_id UUID)
RETURNS TABLE (
    average_rating NUMERIC,
    total_reviews INTEGER
) 
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
    SELECT 
        COALESCE(AVG(rating), 0)::NUMERIC(3,2) as average_rating,
        COUNT(*)::INTEGER as total_reviews
    FROM public.reviews
    INNER JOIN public.job_requests ON job_requests.id = reviews.job_request_id
    WHERE job_requests.provider_id = p_provider_id;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_provider_rating(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_provider_rating(UUID) TO anon;
