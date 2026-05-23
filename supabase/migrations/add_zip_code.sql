-- Add zip_code column to user_profiles table

ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS zip_code TEXT;

-- Verify column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name = 'zip_code';
