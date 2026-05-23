-- Fix app_settings table if needed

-- Ensure updated_at has default
ALTER TABLE public.app_settings 
ALTER COLUMN updated_at SET DEFAULT now();

-- Add description column if missing
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Test insert (run this to verify it works)
-- INSERT INTO public.app_settings (setting_key, setting_value) 
-- VALUES ('test_key', 'test_value') 
-- ON CONFLICT (setting_key) DO UPDATE SET setting_value = 'test_value', updated_at = now();
