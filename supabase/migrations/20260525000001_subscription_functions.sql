-- ============================================================
-- PostgreSQL functions for provider subscription management.
-- These are the transactional core; the Edge Function calls them.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1. start_provider_trial
--    Returns JSON: { "ok": true } or { "ok": false, "error": "..." }
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.start_provider_trial(
    p_provider_id UUID,
    p_plan_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_state RECORD;
    v_trial_days INTEGER;
    v_now TIMESTAMPTZ := now();
    v_expires TIMESTAMPTZ;
BEGIN
    -- Get trial_days from the plan
    SELECT trial_days INTO v_trial_days
    FROM public.subscription_plans
    WHERE id = p_plan_id AND is_active = true;

    IF v_trial_days IS NULL OR v_trial_days <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'plan_no_trial');
    END IF;

    -- Upsert state row (ensures one exists)
    INSERT INTO public.provider_subscription_state (provider_id)
    VALUES (p_provider_id)
    ON CONFLICT (provider_id) DO NOTHING;

    -- Lock the row for update
    SELECT * INTO v_state
    FROM public.provider_subscription_state
    WHERE provider_id = p_provider_id
    FOR UPDATE;

    -- Rule 1: If trial already used and no reset allowed → deny
    IF v_state.trial_used = true AND v_state.trial_reset_allowed = false THEN
        RETURN jsonb_build_object('ok', false, 'error', 'trial_already_used');
    END IF;

    -- Rule 2: If trial used, reset allowed, but same plan → deny
    IF v_state.trial_used = true
       AND v_state.trial_reset_allowed = true
       AND v_state.trial_plan_id = p_plan_id THEN
        RETURN jsonb_build_object('ok', false, 'error', 'trial_same_plan');
    END IF;

    -- Allowed: start trial
    v_expires := v_now + (v_trial_days || ' days')::INTERVAL;

    -- Update state
    UPDATE public.provider_subscription_state
    SET plan_id = p_plan_id,
        subscription_status = 'trial',
        trial_used = true,
        trial_plan_id = p_plan_id,
        trial_reset_allowed = false,
        updated_at = v_now
    WHERE provider_id = p_provider_id;

    -- Create subscription record
    INSERT INTO public.provider_subscriptions (
        provider_id, plan_id, payment_method, payment_status,
        amount_paid, starts_at, expires_at, admin_notes,
        created_at, updated_at
    ) VALUES (
        p_provider_id, p_plan_id, 'trial', 'completed',
        0.0, v_now, v_expires,
        'Free trial - ' || v_trial_days || ' days',
        v_now, v_now
    );

    -- Un-pause provider services
    UPDATE public.provider_services
    SET is_paused = false
    WHERE provider_id = p_provider_id;

    RETURN jsonb_build_object(
        'ok', true,
        'subscription_status', 'trial',
        'expires_at', v_expires
    );
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 2. activate_provider_subscription
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.activate_provider_subscription(
    p_provider_id UUID,
    p_plan_id UUID,
    p_billing_cycle TEXT DEFAULT 'monthly',
    p_amount NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'online'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_expires TIMESTAMPTZ;
BEGIN
    -- Calculate expiration
    IF p_billing_cycle = 'yearly' THEN
        v_expires := v_now + INTERVAL '365 days';
    ELSE
        v_expires := v_now + INTERVAL '30 days';
    END IF;

    -- Upsert state row
    INSERT INTO public.provider_subscription_state (provider_id)
    VALUES (p_provider_id)
    ON CONFLICT (provider_id) DO NOTHING;

    -- Update state
    UPDATE public.provider_subscription_state
    SET plan_id = p_plan_id,
        subscription_status = 'active',
        updated_at = v_now
    WHERE provider_id = p_provider_id;

    -- Create subscription record
    INSERT INTO public.provider_subscriptions (
        provider_id, plan_id, payment_method, payment_status,
        amount_paid, starts_at, expires_at,
        created_at, updated_at
    ) VALUES (
        p_provider_id, p_plan_id, p_payment_method, 'completed',
        p_amount, v_now, v_expires,
        v_now, v_now
    );

    -- Un-pause provider services
    UPDATE public.provider_services
    SET is_paused = false
    WHERE provider_id = p_provider_id;

    RETURN jsonb_build_object(
        'ok', true,
        'subscription_status', 'active',
        'expires_at', v_expires
    );
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 3. expire_provider_subscription
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_provider_subscription(
    p_provider_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update state
    UPDATE public.provider_subscription_state
    SET subscription_status = 'paused',
        plan_id = NULL,
        updated_at = now()
    WHERE provider_id = p_provider_id;

    -- Pause all provider services
    UPDATE public.provider_services
    SET is_paused = true
    WHERE provider_id = p_provider_id;

    RETURN jsonb_build_object('ok', true, 'subscription_status', 'paused');
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 4. complete_paid_month
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_paid_month(
    p_provider_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_paid INTEGER;
BEGIN
    UPDATE public.provider_subscription_state
    SET paid_months = paid_months + 1,
        trial_reset_allowed = true,
        updated_at = now()
    WHERE provider_id = p_provider_id
    RETURNING paid_months INTO v_paid;

    RETURN jsonb_build_object(
        'ok', true,
        'paid_months', COALESCE(v_paid, 0),
        'trial_reset_allowed', true
    );
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 5. get_provider_subscription_state
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_provider_subscription_state(
    p_provider_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_state RECORD;
BEGIN
    SELECT * INTO v_state
    FROM public.provider_subscription_state
    WHERE provider_id = p_provider_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'subscription_status', 'inactive',
            'trial_used', false,
            'paid_months', 0,
            'trial_reset_allowed', false,
            'plan_id', null,
            'trial_plan_id', null
        );
    END IF;

    RETURN jsonb_build_object(
        'subscription_status', v_state.subscription_status,
        'trial_used', v_state.trial_used,
        'paid_months', v_state.paid_months,
        'trial_reset_allowed', v_state.trial_reset_allowed,
        'plan_id', v_state.plan_id,
        'trial_plan_id', v_state.trial_plan_id
    );
END;
$$;
