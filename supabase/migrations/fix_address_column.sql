-- Fix address column in user_profiles

-- Check if address column exists, add if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'address'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN address TEXT;
        RAISE NOTICE 'Added address column to user_profiles';
    ELSE
        RAISE NOTICE 'address column already exists';
    END IF;
END $$;

-- Also ensure lat/lng columns exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'address_lat'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN address_lat FLOAT;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'address_lng'
    ) THEN
        ALTER TABLE public.user_profiles ADD COLUMN address_lng FLOAT;
    END IF;
END $$;

-- Test: Update a profile to verify it works
-- UPDATE public.user_profiles SET address = 'Test Address', address_lat = 20.5, address_lng = -87.2 WHERE id = 'your-user-id';
