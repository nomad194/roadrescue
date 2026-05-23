-- Fix address columns in user_profiles table

-- Check current columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN ('address', 'address_lat', 'address_lng', 'selected_state_id', 'selected_city_id');

-- Add columns if they don't exist
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS address_lat FLOAT,
ADD COLUMN IF NOT EXISTS address_lng FLOAT;

-- Ensure RLS allows updates
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies and recreate
DROP POLICY IF EXISTS "user_profiles_all" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_self" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_admin" ON public.user_profiles;

-- Allow all authenticated users to read/update their own profiles
CREATE POLICY "user_profiles_select" ON public.user_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "user_profiles_update" ON public.user_profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY "user_profiles_insert" ON public.user_profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

-- Test update
UPDATE public.user_profiles 
SET address = 'Test Address', address_lat = 20.5, address_lng = -87.2
WHERE id = '3a433609-e41e-42bd-9b98-854dc5a0dd8a';

SELECT id, address, address_lat, address_lng FROM public.user_profiles WHERE id = '3a433609-e41e-42bd-9b98-854dc5a0dd8a';
