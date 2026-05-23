-- Fix foreign key mismatch - provider_subscriptions references wrong table

-- Check current foreign key
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'provider_subscriptions';

-- Drop existing foreign key if it references wrong table
ALTER TABLE public.provider_subscriptions 
DROP CONSTRAINT IF EXISTS provider_subscriptions_plan_id_fkey;

-- Add foreign key to subscription_plans (the table Flutter uses)
ALTER TABLE public.provider_subscriptions
ADD CONSTRAINT provider_subscriptions_plan_id_fkey
FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(id) ON DELETE SET NULL;

-- Verify
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'provider_subscriptions';
