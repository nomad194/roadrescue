-- Fix app_settings schema - add setting_type column if missing

-- Check current columns
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'app_settings' 
ORDER BY ordinal_position;

-- Add setting_type column if it doesn't exist
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS setting_type TEXT DEFAULT 'string';

-- Make setting_type nullable to avoid issues
ALTER TABLE public.app_settings 
ALTER COLUMN setting_type DROP NOT NULL;

-- Set default value for existing rows
UPDATE public.app_settings 
SET setting_type = 'string' 
WHERE setting_type IS NULL;

-- Add updated_at default if missing
ALTER TABLE public.app_settings 
ALTER COLUMN updated_at SET DEFAULT now();

-- Verify fix
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'app_settings';
