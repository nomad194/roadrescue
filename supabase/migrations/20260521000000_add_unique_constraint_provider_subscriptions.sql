-- Add unique constraint on provider_id to provider_subscriptions table
-- This allows upsert operations with onConflict: 'provider_id' to work correctly
-- A provider should only have one active subscription at a time

ALTER TABLE public.provider_subscriptions
ADD CONSTRAINT provider_subscriptions_provider_id_key UNIQUE (provider_id);
