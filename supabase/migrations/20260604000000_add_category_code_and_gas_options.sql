-- Migration: Add category code and gas_amount_options for Gas Service configurability
-- ============================================================

-- 1. Add stable category code for service-type identification
ALTER TABLE public.service_categories
ADD COLUMN IF NOT EXISTS code TEXT;

-- 2. Add per-category configurable gas amounts (only used by fuel categories)
ALTER TABLE public.service_categories
ADD COLUMN IF NOT EXISTS gas_amount_options JSONB DEFAULT '[]'::jsonb;

-- 3. Backfill codes for existing seeded categories (idempotent)
UPDATE public.service_categories SET code = 'towing'        WHERE name = 'Towing' AND code IS NULL;
UPDATE public.service_categories SET code = 'jump_start'    WHERE name = 'Jump Start' AND code IS NULL;
UPDATE public.service_categories SET code = 'flat_tire'    WHERE name = 'Flat Tire' AND code IS NULL;
UPDATE public.service_categories SET code = 'lockout'      WHERE name = 'Lockout' AND code IS NULL;
UPDATE public.service_categories SET code = 'fuel_delivery' WHERE name = 'Fuel Delivery' AND code IS NULL;
UPDATE public.service_categories SET code = 'battery'       WHERE name = 'Battery' AND code IS NULL;
