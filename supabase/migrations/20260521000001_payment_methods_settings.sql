-- Migration: Payment Methods Settings and Table
-- Adds global payment toggles and payment_methods table for admin configuration

-- 1. Add global payment method enabled settings to app_settings
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description)
VALUES
  ('online_payment_enabled', 'true', 'boolean', 'Enable online (Stripe) payments globally'),
  ('cash_payment_enabled', 'true', 'boolean', 'Enable cash payments globally')
ON CONFLICT (setting_key) DO NOTHING;

-- 2. Create payment_methods table for admin-configurable payment options
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT DEFAULT 'payment',
    is_enabled BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    config JSONB DEFAULT '{}',
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_code ON public.payment_methods(code);
CREATE INDEX IF NOT EXISTS idx_payment_methods_enabled ON public.payment_methods(is_enabled);

-- 3. Enable RLS on payment_methods
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

-- Everyone can read enabled payment methods
DROP POLICY IF EXISTS "public_read_payment_methods" ON public.payment_methods;
CREATE POLICY "public_read_payment_methods" ON public.payment_methods
  FOR SELECT TO public USING (is_enabled = true);

-- Admins can manage all payment methods
DROP POLICY IF EXISTS "admin_manage_payment_methods" ON public.payment_methods;
CREATE POLICY "admin_manage_payment_methods" ON public.payment_methods
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 4. Seed default payment methods (CASH and Stripe)
INSERT INTO public.payment_methods (code, name, description, icon_name, is_enabled, is_default, display_order, config)
VALUES
  ('cash', 'Cash', 'Pay with cash on delivery', 'payments_outlined', true, true, 1, '{}'),
  ('stripe', 'Stripe', 'Secure online card payments via Stripe', 'credit_card', true, true, 2, '{"requires_setup": true, "setup_guide": "Configure Stripe in your dashboard"}'::jsonb)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon_name = EXCLUDED.icon_name,
  display_order = EXCLUDED.display_order;

-- 5. Enable realtime for payment_methods
ALTER TABLE public.payment_methods REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_methods;
  END IF;
END $$;
