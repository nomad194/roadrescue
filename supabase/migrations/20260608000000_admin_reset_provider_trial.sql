-- ============================================================
-- Admin: Reset provider trial status
-- Allows an admin to reset a provider's trial so they can
try a plan again.
-- ============================================================

CREATE OR REPLACE FUNCTION public.reset_provider_trial(
    p_provider_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Ensure the row exists
    INSERT INTO public.provider_subscription_state (provider_id)
    VALUES (p_provider_id)
    ON CONFLICT (provider_id) DO NOTHING;

    -- Reset trial fields and mark subscription as inactive
    UPDATE public.provider_subscription_state
    SET trial_used = false,
        trial_reset_allowed = true,
        subscription_status = 'inactive',
        plan_id = NULL,
        trial_plan_id = NULL,
        updated_at = now()
    WHERE provider_id = p_provider_id;

    RETURN jsonb_build_object('ok', true);
END;
$$;
