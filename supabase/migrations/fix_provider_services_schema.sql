-- Fix provider_services schema mismatch

-- Check current columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'provider_services' 
ORDER BY ordinal_position;

-- If the table has 'service_category' instead of 'category_id', we need to fix it
-- First, add the correct column if missing
ALTER TABLE public.provider_services 
ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES public.service_categories(id);

-- Add other missing columns for pricing features
ALTER TABLE public.provider_services 
ADD COLUMN IF NOT EXISTS distance_rules JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.provider_services 
ADD COLUMN IF NOT EXISTS time_surcharges JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.provider_services 
ADD COLUMN IF NOT EXISTS supported_vehicle_sizes JSONB DEFAULT '["sedan", "suv", "van", "pickup"]'::jsonb;

-- Migrate data from old column if it exists
DO $$
BEGIN
  -- Check if old column exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'provider_services' AND column_name = 'service_category'
  ) THEN
    -- Try to map text categories to integer IDs (best effort)
    UPDATE public.provider_services ps
    SET category_id = sc.id
    FROM public.service_categories sc
    WHERE ps.service_category = sc.name;
    
    -- Drop the old column after migration
    ALTER TABLE public.provider_services DROP COLUMN service_category;
  END IF;
END $$;

-- Verify fix
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'provider_services';
