-- Migration: Booking & Payment Flow
-- Adds payment_methods to job_requests/quotes, WhatsApp toggle, en_route status

-- 1. Add accepted_payment_methods to job_requests (set by provider when quoting)
ALTER TABLE job_requests
  ADD COLUMN IF NOT EXISTS accepted_payment_methods TEXT DEFAULT 'cash,online',
  ADD COLUMN IF NOT EXISTS payment_method_used TEXT;

-- 2. Add en_route status support (extend existing job_status check if exists)
DO $$
BEGIN
  -- Add en_route to allowed statuses if there's a check constraint
  -- We just ensure the column accepts the value by updating any constraint
  BEGIN
    ALTER TABLE job_requests DROP CONSTRAINT IF EXISTS job_requests_job_status_check;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

-- 3. Add WhatsApp feature toggle to app_settings
INSERT INTO app_settings (setting_key, setting_value, setting_type, description)
VALUES
  ('whatsapp_chat_enabled', 'true', 'boolean', 'Show WhatsApp chat button after booking confirmation'),
  ('whatsapp_admin_number', '', 'string', 'Admin WhatsApp number (optional fallback)')
ON CONFLICT (setting_key) DO NOTHING;

-- 4. Add provider_payment_methods to user_profiles (provider's accepted payment types)
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS accepted_payment_methods TEXT DEFAULT 'cash,online';

-- 5. Seed post-payment settings if not present
INSERT INTO app_settings (setting_key, setting_value, setting_type, description)
VALUES
  ('post_payment_screen_online', 'true', 'boolean', 'Show post-payment receipt for online payments'),
  ('post_payment_screen_cash', 'false', 'boolean', 'Show post-payment receipt for cash payments')
ON CONFLICT (setting_key) DO NOTHING;
