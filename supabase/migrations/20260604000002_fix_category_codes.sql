-- Migration: Fix category codes for Gas and Flat Tire services
-- ============================================================

-- First, let's see what categories exist (run this manually to check)
-- SELECT id, name, code FROM public.service_categories;

-- Update fuel/gas category code (covers common naming variations)
UPDATE public.service_categories 
SET code = 'fuel_delivery' 
WHERE code IS NULL 
  AND (
    LOWER(name) LIKE '%fuel%' 
    OR LOWER(name) LIKE '%gas%' 
    OR LOWER(name) LIKE '%diesel%'
    OR LOWER(name) LIKE '%combustible%'  -- Spanish
    OR LOWER(name) LIKE '%carburant%'    -- French
  );

-- Update flat tire category code (covers common naming variations)
UPDATE public.service_categories 
SET code = 'flat_tire' 
WHERE code IS NULL 
  AND (
    LOWER(name) LIKE '%flat%tire%'
    OR LOWER(name) LIKE '%tire%flat%'
    OR LOWER(name) LIKE '%puncture%'     -- Common synonym
    OR LOWER(name) LIKE '%ponchada%'     -- Spanish
    OR LOWER(name) LIKE '%crev%'         -- French (crevé)
    OR LOWER(name) LIKE '%furo%'         -- Portuguese (furado)
  );

-- Ensure other categories have codes too
UPDATE public.service_categories SET code = 'towing'        WHERE LOWER(name) LIKE '%tow%' AND code IS NULL;
UPDATE public.service_categories SET code = 'jump_start'    WHERE (LOWER(name) LIKE '%jump%' OR LOWER(name) LIKE '%start%') AND code IS NULL;
UPDATE public.service_categories SET code = 'lockout'       WHERE LOWER(name) LIKE '%lock%' AND code IS NULL;
UPDATE public.service_categories SET code = 'battery'       WHERE LOWER(name) LIKE '%batter%' AND code IS NULL;

-- Set default gas amounts for fuel categories (if empty)
UPDATE public.service_categories 
SET gas_amount_options = '[50, 100, 200, 500]'::jsonb
WHERE code = 'fuel_delivery' 
  AND (gas_amount_options IS NULL OR gas_amount_options = '[]'::jsonb);

-- Verify the results
SELECT id, name, code, gas_amount_options 
FROM public.service_categories 
ORDER BY code NULLS LAST, name;
