-- Migration: Add service-specific columns to job_requests
-- ============================================================

-- Gas Service fields
ALTER TABLE public.job_requests
ADD COLUMN IF NOT EXISTS fuel_type TEXT;

ALTER TABLE public.job_requests
ADD COLUMN IF NOT EXISTS fuel_amount NUMERIC;

-- Flat Tire Service fields
ALTER TABLE public.job_requests
ADD COLUMN IF NOT EXISTS tire_position TEXT;

ALTER TABLE public.job_requests
ADD COLUMN IF NOT EXISTS tire_action TEXT;
