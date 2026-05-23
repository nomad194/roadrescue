-- Fix job_requests table - add missing status column and other required columns

-- Check current columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'job_requests' 
ORDER BY ordinal_position;

-- Add status column if missing
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- Add customer_lat column if missing (for distance calculations)
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS customer_lat FLOAT;

-- Add customer_lng column if missing (for distance calculations)
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS customer_lng FLOAT;

-- Add customer_state_id column if missing
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS customer_state_id UUID REFERENCES public.states(id);

-- Add customer_city_id column if missing
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS customer_city_id UUID REFERENCES public.cities(id);

-- Add provider_id column if missing
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS provider_id UUID REFERENCES public.user_profiles(id);

-- Add service_type column if missing
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS service_type TEXT;

-- Verify fix
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'job_requests';
