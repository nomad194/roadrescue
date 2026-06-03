-- ============================================================
-- Make FK columns nullable to support account deletion anonymization
-- ============================================================

DO $$
BEGIN
    -- job_requests: allow anonymizing customer_id for completed requests
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'job_requests') THEN
        ALTER TABLE public.job_requests ALTER COLUMN customer_id DROP NOT NULL;
    END IF;

    -- bookings: allow anonymizing both customer_id and provider_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bookings') THEN
        ALTER TABLE public.bookings ALTER COLUMN customer_id DROP NOT NULL;
        ALTER TABLE public.bookings ALTER COLUMN provider_id DROP NOT NULL;
    END IF;

    -- payments: allow anonymizing customer_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payments') THEN
        ALTER TABLE public.payments ALTER COLUMN customer_id DROP NOT NULL;
    END IF;

    -- provider_subscriptions: allow clearing provider_id before deleting user
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'provider_subscriptions') THEN
        ALTER TABLE public.provider_subscriptions ALTER COLUMN provider_id DROP NOT NULL;
    END IF;

    -- push_tokens: allow clearing user_id before deleting user
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'push_tokens') THEN
        ALTER TABLE public.push_tokens ALTER COLUMN user_id DROP NOT NULL;
    END IF;

    -- provider_documents: allow clearing provider_id before deleting user
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'provider_documents') THEN
        ALTER TABLE public.provider_documents ALTER COLUMN provider_id DROP NOT NULL;
    END IF;
END $$;
