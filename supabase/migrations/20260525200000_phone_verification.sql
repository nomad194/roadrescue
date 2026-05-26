-- Migration: Add phone verification support for MFA
-- Created: 2025-05-25

-- Add phone_verified_at column to user_profiles
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ;

-- Ensure phone column exists (may already exist from earlier migrations)
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- Create helper function to check if phone is verified
-- Admins are exempt from phone verification
CREATE OR REPLACE FUNCTION public.is_phone_verified(p_uid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role TEXT;
BEGIN
    -- Get user role
    SELECT role INTO v_role FROM public.user_profiles WHERE id = p_uid;
    
    -- Admins are exempt from phone verification
    IF v_role = 'admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Check if phone is verified for non-admin users
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = p_uid 
        AND phone_verified_at IS NOT NULL
    );
END;
$$;

-- Add comment for documentation
COMMENT ON COLUMN public.user_profiles.phone_verified_at IS 'Timestamp when phone number was verified via SMS MFA';
COMMENT ON COLUMN public.user_profiles.phone IS 'User phone number for SMS MFA and contact';
COMMENT ON FUNCTION public.is_phone_verified(UUID) IS 'Returns true if user has verified their phone number';

-- Enable RLS for the new columns (inherits existing policies)
-- No new policies needed as existing user_profiles policies cover these columns

-- Backfill: Mark all existing users as phone verified so they don't have to re-verify
-- This applies to existing customers and providers
UPDATE public.user_profiles 
SET phone_verified_at = NOW() 
WHERE phone_verified_at IS NULL 
AND role IN ('customer', 'provider');
