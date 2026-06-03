-- Migration: Add service_icon_image_url to job_requests

ALTER TABLE public.job_requests
ADD COLUMN IF NOT EXISTS service_icon_image_url TEXT;
