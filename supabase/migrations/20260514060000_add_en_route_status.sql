-- Migration: Add en_route to job_status enum
-- Fixes "On My Way" button failure caused by missing enum value

-- Add 'en_route' to the job_status enum if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'en_route'
      AND enumtypid = (
        SELECT oid FROM pg_type WHERE typname = 'job_status' AND typnamespace = (
          SELECT oid FROM pg_namespace WHERE nspname = 'public'
        )
      )
  ) THEN
    ALTER TYPE public.job_status ADD VALUE 'en_route';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not add en_route to job_status enum: %', SQLERRM;
END $$;
