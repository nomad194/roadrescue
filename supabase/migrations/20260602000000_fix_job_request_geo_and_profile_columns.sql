-- ============================================================
-- Fix missing geo/address columns in job_requests and user_profiles
-- Ensures customer app can create job requests with GPS coordinates
-- ============================================================

-- 1. Create states table if missing (needed for customer_state_id FK)
CREATE TABLE IF NOT EXISTS public.states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    country TEXT DEFAULT 'Mexico',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Add state_id to cities if missing
ALTER TABLE public.cities 
ADD COLUMN IF NOT EXISTS state_id UUID REFERENCES public.states(id) ON DELETE CASCADE;

-- 3. Add missing address/geo columns to user_profiles
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS address_lat FLOAT,
ADD COLUMN IF NOT EXISTS address_lng FLOAT,
ADD COLUMN IF NOT EXISTS selected_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS selected_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL;

-- 4. Add missing columns to job_requests
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS service_icon_image_url TEXT,
ADD COLUMN IF NOT EXISTS customer_lat FLOAT,
ADD COLUMN IF NOT EXISTS customer_lng FLOAT,
ADD COLUMN IF NOT EXISTS customer_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS customer_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL;

-- 5. Add indexes for geo queries if missing
CREATE INDEX IF NOT EXISTS idx_job_requests_location ON public.job_requests(customer_lat, customer_lng);
CREATE INDEX IF NOT EXISTS idx_job_requests_city ON public.job_requests(customer_city_id);
CREATE INDEX IF NOT EXISTS idx_job_requests_state ON public.job_requests(customer_state_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_location ON public.user_profiles(address_lat, address_lng);
CREATE INDEX IF NOT EXISTS idx_user_profiles_state ON public.user_profiles(selected_state_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_city ON public.user_profiles(selected_city_id);
