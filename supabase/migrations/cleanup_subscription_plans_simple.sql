-- ============================================================
-- SIMPLE CLEANUP: Mark duplicate/test plans as inactive
-- This is safer than deleting (avoids foreign key issues)
-- ============================================================

-- Step 1: Show all plans with subscriber counts
SELECT id, name, price_monthly, is_active, created_at, 
       (SELECT COUNT(*) FROM public.provider_subscriptions ps WHERE ps.plan_id = sp.id) as subscribers
FROM public.subscription_plans sp
ORDER BY subscribers DESC, created_at ASC;

-- Step 2: Mark duplicate plans (same name, newer created_at) as inactive
-- Keep the oldest plan for each name that has subscribers
UPDATE public.subscription_plans sp1
SET is_active = false, is_enabled = false
WHERE id IN (
    SELECT id FROM (
        SELECT id, name, created_at,
               ROW_NUMBER() OVER (PARTITION BY name ORDER BY created_at ASC) as rn
        FROM public.subscription_plans
        WHERE name IN ('Basic', 'Professional', 'Enterprise')
    ) sub
    WHERE rn > 1
);

-- Step 3: Mark test plans (no subscribers, created recently) as inactive
-- Except keep Basic/Professional/Enterprise
UPDATE public.subscription_plans
SET is_active = false, is_enabled = false
WHERE id NOT IN (
    -- Keep plans that have subscribers
    SELECT DISTINCT plan_id FROM public.provider_subscriptions WHERE plan_id IS NOT NULL
)
AND created_at > CURRENT_DATE - INTERVAL '1 day'
AND name NOT IN ('Basic', 'Professional', 'Enterprise');

-- Step 4: Ensure the 3 main plans are active (update existing, don't insert new)
UPDATE public.subscription_plans 
SET is_active = true, is_enabled = true
WHERE name IN ('Basic', 'Professional', 'Enterprise');

-- Step 5: Verify final state
SELECT id, name, price_monthly, is_active, is_enabled,
       (SELECT COUNT(*) FROM public.provider_subscriptions ps WHERE ps.plan_id = sp.id) as subscribers
FROM public.subscription_plans sp
WHERE is_active = true
ORDER BY price_monthly;
