-- ============================================================
-- RoadRescue: Payments, Subscriptions, Notifications, Language
-- ============================================================

-- 1. TYPES
DROP TYPE IF EXISTS public.subscription_status CASCADE;
CREATE TYPE public.subscription_status AS ENUM ('active', 'trialing', 'past_due', 'canceled', 'incomplete');

DROP TYPE IF EXISTS public.payment_status CASCADE;
CREATE TYPE public.payment_status AS ENUM ('pending', 'succeeded', 'failed', 'refunded');

-- 2. APP SETTINGS TABLE (commission, default language, etc.)
CREATE TABLE IF NOT EXISTS public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT NOT NULL UNIQUE,
  setting_value TEXT NOT NULL DEFAULT '',
  setting_type TEXT NOT NULL DEFAULT 'string',
  description TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_settings_key ON public.app_settings(setting_key);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_app_settings" ON public.app_settings;
CREATE POLICY "public_read_app_settings" ON public.app_settings
  FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "admin_manage_app_settings" ON public.app_settings;
CREATE POLICY "admin_manage_app_settings" ON public.app_settings
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  );

-- 3. SUBSCRIPTION PLANS TABLE
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price_monthly NUMERIC(10,2) NOT NULL DEFAULT 0,
  price_yearly NUMERIC(10,2),
  trial_days INTEGER DEFAULT 0,
  discount_percent NUMERIC(5,2) DEFAULT 0,
  features JSONB DEFAULT '[]'::jsonb,
  stripe_price_id_monthly TEXT DEFAULT '',
  stripe_price_id_yearly TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  purchase_mode TEXT DEFAULT 'in_app',
  external_url TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_subscription_plans_active ON public.subscription_plans(is_active);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_subscription_plans" ON public.subscription_plans;
CREATE POLICY "public_read_subscription_plans" ON public.subscription_plans
  FOR SELECT TO public USING (is_active = true);

DROP POLICY IF EXISTS "admin_manage_subscription_plans" ON public.subscription_plans;
CREATE POLICY "admin_manage_subscription_plans" ON public.subscription_plans
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  );

-- 4. PROVIDER SUBSCRIPTIONS TABLE
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

CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_provider ON public.provider_subscriptions(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_status ON public.provider_subscriptions(status);

ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "providers_view_own_subscriptions" ON public.provider_subscriptions;
CREATE POLICY "providers_view_own_subscriptions" ON public.provider_subscriptions
  FOR SELECT TO authenticated USING (provider_id = auth.uid());

DROP POLICY IF EXISTS "admin_manage_provider_subscriptions" ON public.provider_subscriptions;
CREATE POLICY "admin_manage_provider_subscriptions" ON public.provider_subscriptions
  FOR ALL TO authenticated
  USING (
    provider_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  )
  WITH CHECK (
    provider_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  );

-- 5. PAYMENTS TABLE (for job booking payments)
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
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

CREATE INDEX IF NOT EXISTS idx_payments_booking ON public.payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_provider ON public.payments(provider_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(payment_status);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_view_own_payments" ON public.payments;
CREATE POLICY "users_view_own_payments" ON public.payments
  FOR SELECT TO authenticated
  USING (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "customers_create_payments" ON public.payments;
CREATE POLICY "customers_create_payments" ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "admin_manage_payments" ON public.payments;
CREATE POLICY "admin_manage_payments" ON public.payments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND (au.raw_user_meta_data->>'role' = 'admin')
    )
  );

-- 6. PUSH NOTIFICATION TOKENS TABLE
CREATE TABLE IF NOT EXISTS public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT DEFAULT 'android',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_user_token ON public.push_tokens(user_id, token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON public.push_tokens(user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_manage_own_push_tokens" ON public.push_tokens;
CREATE POLICY "users_manage_own_push_tokens" ON public.push_tokens
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 7. USER LANGUAGE PREFERENCES
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'en';

-- 8. SEED DEFAULT APP SETTINGS
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description) VALUES
  ('commission_enabled', 'true', 'boolean', 'Enable/disable platform commission on payments'),
  ('commission_percent', '15', 'number', 'Platform commission percentage (0-100)'),
  ('default_language', 'en', 'string', 'Default app language code'),
  ('stripe_connect_enabled', 'true', 'boolean', 'Enable Stripe Connect split payments'),
  ('currency', 'usd', 'string', 'Default currency for payments')
ON CONFLICT (setting_key) DO NOTHING;

-- 9. SEED SAMPLE SUBSCRIPTION PLANS
INSERT INTO public.subscription_plans (name, description, price_monthly, price_yearly, trial_days, discount_percent, features, is_active, purchase_mode) VALUES
  (
    'Basic',
    'Get started with essential features',
    9.99,
    99.99,
    14,
    0,
    '["Up to 10 jobs/month", "Basic profile listing", "Email support"]'::jsonb,
    true,
    'in_app'
  ),
  (
    'Professional',
    'For active providers growing their business',
    24.99,
    249.99,
    14,
    10,
    '["Unlimited jobs", "Priority listing", "Analytics dashboard", "Phone support", "Custom profile badge"]'::jsonb,
    true,
    'in_app'
  ),
  (
    'Enterprise',
    'Full-featured plan for large operations',
    59.99,
    599.99,
    30,
    20,
    '["Everything in Professional", "Dedicated account manager", "API access", "Custom branding", "Multi-vehicle support"]'::jsonb,
    true,
    'in_app'
  )
ON CONFLICT (id) DO NOTHING;
