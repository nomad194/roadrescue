-- Restore payments and provider_subscriptions dropped by master_schema.
-- Uses job_request_id (not legacy bookings.booking_id).

CREATE TABLE IF NOT EXISTS public.provider_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
  stripe_subscription_id TEXT DEFAULT '',
  stripe_customer_id TEXT DEFAULT '',
  status public.subscription_status DEFAULT 'active'::public.subscription_status,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  trial_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_provider
  ON public.provider_subscriptions(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_status
  ON public.provider_subscriptions(status);

CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_request_id UUID REFERENCES public.job_requests(id) ON DELETE SET NULL,
  customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  stripe_payment_intent_id TEXT DEFAULT '',
  stripe_charge_id TEXT DEFAULT '',
  amount NUMERIC(10,2) NOT NULL,
  commission_amount NUMERIC(10,2) DEFAULT 0,
  provider_payout NUMERIC(10,2) DEFAULT 0,
  currency TEXT DEFAULT 'usd',
  payment_status public.payment_status DEFAULT 'pending'::public.payment_status,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_job_request ON public.payments(job_request_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_provider ON public.payments(provider_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_stripe_intent ON public.payments(stripe_payment_intent_id);

ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Drop legacy bookings table (app uses job_requests)
DROP TABLE IF EXISTS public.bookings CASCADE;
