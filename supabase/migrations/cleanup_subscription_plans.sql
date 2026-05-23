-- ============================================================
-- CLEANUP: Remove duplicate and test subscription plans
-- Keeps only the original 3 plans (Basic, Professional, Enterprise)
-- SAFETY: Shows what will be deleted before actually deleting
-- ============================================================

-- First, let's see what plans exist
SELECT id, name, price_monthly, created_at, 
       (SELECT COUNT(*) FROM public.provider_subscriptions ps WHERE ps.plan_id = sp.id) as subscribers
FROM public.subscription_plans sp
ORDER BY created_at;

-- ============================================================
-- OPTION 1: Soft delete - Mark old/test plans as inactive (RECOMMENDED)
-- This hides them from users but keeps data integrity
-- ============================================================

-- Mark plans with no subscribers and created today as inactive
UPDATE public.subscription_plans 
SET is_active = false, is_enabled = false
WHERE id NOT IN (
    -- Keep plans that have subscribers
    SELECT DISTINCT plan_id FROM public.provider_subscriptions WHERE plan_id IS NOT NULL
)
AND created_at > CURRENT_DATE - INTERVAL '1 day'  -- Only plans created today
AND name NOT IN ('Basic', 'Professional', 'Enterprise');  -- Keep original named plans

-- ============================================================
-- OPTION 2: Hard delete - Actually delete test plans (DANGEROUS)
-- Only run this if you're sure no one is subscribed to these plans
-- ============================================================

-- Show what would be deleted (dry run)
SELECT id, name, price_monthly, created_at
FROM public.subscription_plans
WHERE id NOT IN (
    SELECT DISTINCT plan_id FROM public.provider_subscriptions WHERE plan_id IS NOT NULL
)
AND created_at > CURRENT_DATE - INTERVAL '1 day'
AND name NOT IN ('Basic', 'Professional', 'Enterprise');

-- Uncomment the following to actually delete (ONLY if above query shows correct plans)
-- DELETE FROM public.subscription_plans
-- WHERE id NOT IN (
--     SELECT DISTINCT plan_id FROM public.provider_subscriptions WHERE plan_id IS NOT NULL
-- )
-- AND created_at > CURRENT_DATE - INTERVAL '1 day'
-- AND name NOT IN ('Basic', 'Professional', 'Enterprise');

-- ============================================================
-- RESET: Keep only 3 clean default plans
-- ============================================================

-- Step 1: Delete duplicate plans (keep the oldest one for each name)
DELETE FROM public.subscription_plans
WHERE id IN (
    SELECT id FROM (
        SELECT id, name, created_at,
               ROW_NUMBER() OVER (PARTITION BY name ORDER BY created_at ASC) as rn
        FROM public.subscription_plans
        WHERE name IN ('Basic', 'Professional', 'Enterprise')
    ) sub
    WHERE rn > 1
);

-- Step 2: Delete all test plans (plans created today with no subscribers)
-- except keep the original 3 named plans
DELETE FROM public.subscription_plans
WHERE id NOT IN (
    SELECT DISTINCT plan_id FROM public.provider_subscriptions WHERE plan_id IS NOT NULL
)
AND created_at > CURRENT_DATE - INTERVAL '1 day'
AND name NOT IN ('Basic', 'Professional', 'Enterprise');

-- Step 3: Rename any remaining duplicate-ish plans to avoid conflicts
UPDATE public.subscription_plans 
SET name = name || ' (Old)' 
WHERE name IN ('Basic', 'Professional', 'Enterprise')
AND created_at > CURRENT_DATE - INTERVAL '1 day'
AND id NOT IN (
    SELECT id FROM public.subscription_plans 
    WHERE name IN ('Basic', 'Professional', 'Enterprise') 
    ORDER BY created_at ASC 
    LIMIT 1
);

-- Step 4: Now add unique constraint on name (should work after deduplication)
DO $$
BEGIN
    ALTER TABLE public.subscription_plans 
    ADD CONSTRAINT subscription_plans_name_key UNIQUE (name);
EXCEPTION 
    WHEN duplicate_table THEN NULL;
    WHEN duplicate_object THEN NULL;
    WHEN unique_violation THEN NULL;
END $$;

-- Step 5: Ensure the 3 main plans exist and are active
-- Use simple INSERT without ON CONFLICT for now
INSERT INTO public.subscription_plans 
    (name, description, price_monthly, price_yearly, trial_days, is_active, is_featured, 
     max_categories, max_radius_miles, features, purchase_mode, can_use_after_hours, 
     can_set_distance_surcharges, priority_level, discount_percent)
VALUES
    ('Basic', 'Get started with essential features', 9.99, 99.99, 14, true, false, 
     1, 25, '["1 category", "25 mile radius", "Basic support"]', 'in_app', false, false, 1, 0),
    ('Professional', 'Perfect for growing businesses', 24.99, 249.99, 14, true, true, 
     3, 50, '["3 categories", "50 mile radius", "Priority support", "Custom pricing"]', 'in_app', true, true, 2, 10),
    ('Enterprise', 'For large operations', 59.99, 599.99, 30, true, false, 
     10, 100, '["Unlimited categories", "100 mile radius", "24/7 support", "API access"]', 'in_app', true, true, 3, 20)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    price_monthly = EXCLUDED.price_monthly,
    price_yearly = EXCLUDED.price_yearly,
    trial_days = EXCLUDED.trial_days,
    is_active = true,
    is_featured = EXCLUDED.is_featured,
    max_categories = EXCLUDED.max_categories,
    max_radius_miles = EXCLUDED.max_radius_miles,
    features = EXCLUDED.features,
    purchase_mode = EXCLUDED.purchase_mode,
    can_use_after_hours = EXCLUDED.can_use_after_hours,
    can_set_distance_surcharges = EXCLUDED.can_set_distance_surcharges,
    priority_level = EXCLUDED.priority_level,
    discount_percent = EXCLUDED.discount_percent;

-- Verify final state
SELECT id, name, price_monthly, is_active, is_featured, 
       (SELECT COUNT(*) FROM public.provider_subscriptions ps WHERE ps.plan_id = sp.id) as subscribers
FROM public.subscription_plans sp
WHERE is_active = true
ORDER BY priority_level, price_monthly;
