-- Fix subscription_plans schema - add missing columns

-- Check current columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'subscription_plans' 
ORDER BY ordinal_position;

-- Add badge_text column if missing
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS badge_text TEXT;

-- Add display_order column if missing
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Add is_enabled column if missing (for toggling visibility)
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS is_enabled BOOLEAN DEFAULT true;

-- Add discount_percent column if missing
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS discount_percent INTEGER DEFAULT 0;

-- Add price_yearly column if missing
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS price_yearly NUMERIC(10,2);

-- Add description column if missing
ALTER TABLE public.subscription_plans 
ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';

-- Verify fix
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'subscription_plans';
