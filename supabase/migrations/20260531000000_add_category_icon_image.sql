-- Migration: Add icon_image_url to service_categories

ALTER TABLE public.service_categories
ADD COLUMN IF NOT EXISTS icon_image_url TEXT;
