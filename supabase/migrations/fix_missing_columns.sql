-- Add missing columns that Flutter code expects

-- Add is_enabled to payment_methods
ALTER TABLE public.payment_methods 
ADD COLUMN IF NOT EXISTS is_enabled BOOLEAN DEFAULT true;

-- Add badge_text to subscription_plans (or plans table)
ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS badge_text TEXT;

-- Also ensure display_order exists
ALTER TABLE public.payment_methods 
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

ALTER TABLE public.plans 
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Add icon_name if missing
ALTER TABLE public.payment_methods 
ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'payment';
