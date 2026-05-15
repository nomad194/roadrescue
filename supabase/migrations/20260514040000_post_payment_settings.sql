-- Migration: post_payment_screen_settings
-- Adds app_settings rows for post-payment screen toggles

DO $$
BEGIN
  INSERT INTO app_settings (setting_key, setting_value, setting_type, description)
  VALUES
    ('post_payment_screen_online', 'true', 'boolean', 'Show post-payment receipt screen after online (Stripe) payments'),
    ('post_payment_screen_cash', 'false', 'boolean', 'Show post-payment receipt screen after cash payments')
  ON CONFLICT (setting_key) DO NOTHING;
END $$;
