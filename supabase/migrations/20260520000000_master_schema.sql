-- ============================================================
-- ROADRESCUE ABSOLUTE MASTER SCHEMA RECONSTRUCTION
-- Rebuilds EVERYTHING: Tables, Types, Triggers, Seed Data,
-- Real-time, and Permissions.
-- ============================================================

-- ─── 0. CLEAN WIPE ──────────────────────────────────────────
-- Remove everything in the public schema to ensure a fresh start

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_provider_geo_update ON public.user_profiles;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.sync_provider_geo_to_services() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_role() CASCADE;

DROP TABLE IF EXISTS public.job_requests CASCADE;
DROP TABLE IF EXISTS public.provider_services CASCADE;
DROP TABLE IF EXISTS public.service_categories CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;
DROP TABLE IF EXISTS public.provider_subscriptions CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.push_tokens CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.geo_zones CASCADE;
DROP TABLE IF EXISTS public.cities CASCADE;
DROP TABLE IF EXISTS public.states CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.app_content CASCADE;
DROP TABLE IF EXISTS public.reviews CASCADE;

DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.job_status CASCADE;
DROP TYPE IF EXISTS public.urgency_level CASCADE;
DROP TYPE IF EXISTS public.subscription_status CASCADE;
DROP TYPE IF EXISTS public.payment_status CASCADE;

-- ─── 1. EXTENSIONS & TYPES ────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE public.user_role AS ENUM ('customer', 'provider', 'admin');
CREATE TYPE public.job_status AS ENUM (
    'pending', 'quoted', 'accepted', 'confirmed', 'en_route',
    'in_progress', 'awaiting_confirmation', 'awaiting_reconfirmation',
    'completed', 'cancelled', 'disputed'
);
CREATE TYPE public.urgency_level AS ENUM ('standard', 'urgent');
CREATE TYPE public.subscription_status AS ENUM ('active', 'trialing', 'past_due', 'canceled', 'incomplete');
CREATE TYPE public.payment_status AS ENUM ('pending', 'succeeded', 'failed', 'refunded');

-- ─── 2. CORE TABLES ──────────────────────────────────────────

-- Geographic Data
CREATE TABLE public.states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    country TEXT DEFAULT 'Mexico',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    state TEXT NOT NULL,
    state_id UUID REFERENCES public.states(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.geo_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_id UUID REFERENCES public.cities(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    timezone TEXT DEFAULT 'America/Cancun',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Profiles
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    phone TEXT DEFAULT '',
    role public.user_role NOT NULL DEFAULT 'customer'::public.user_role,
    business_name TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    address TEXT,
    address_lat FLOAT,
    address_lng FLOAT,
    selected_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL,
    selected_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL,
    selected_geo_zone_id UUID REFERENCES public.geo_zones(id) ON DELETE SET NULL,
    service_range_miles INTEGER DEFAULT 25,
    is_available BOOLEAN DEFAULT true,
    preferred_language TEXT DEFAULT 'en',
    accepted_payment_methods TEXT DEFAULT 'cash,online',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Marketplace Metadata
CREATE TABLE public.service_categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    name_translations JSONB DEFAULT '{}'::jsonb,
    icon_emoji TEXT DEFAULT '🔧',
    vehicle_sizes JSONB DEFAULT '["sedan", "suv", "van", "pickup", "motorcycle", "large_truck"]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0
);

CREATE TABLE public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    name_translations JSONB DEFAULT '{}'::jsonb,
    description TEXT DEFAULT '',
    description_translations JSONB DEFAULT '{}'::jsonb,
    price_monthly NUMERIC(10,2) NOT NULL DEFAULT 0,
    price_yearly NUMERIC(10,2),
    trial_days INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    max_radius_miles INTEGER DEFAULT 25,
    max_categories INTEGER DEFAULT 2,
    can_use_after_hours BOOLEAN DEFAULT false,
    can_set_distance_surcharges BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Specific Provider Configuration
CREATE TABLE public.provider_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES public.service_categories(id) ON DELETE CASCADE,
    base_price NUMERIC(10,2) DEFAULT 0,
    distance_rules JSONB DEFAULT '[]'::jsonb,
    time_surcharges JSONB DEFAULT '[]'::jsonb,
    supported_vehicle_sizes JSONB DEFAULT '[]'::jsonb,
    geo_zone_id UUID REFERENCES public.geo_zones(id) ON DELETE SET NULL,
    service_range_miles INTEGER,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Core Transactions (HANDSHAKE READY)
CREATE TABLE public.job_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL,
    service_icon TEXT DEFAULT 'build',
    service_icon_image_url TEXT,
    vehicle_size TEXT,
    address TEXT NOT NULL,
    customer_lat FLOAT,
    customer_lng FLOAT,
    customer_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL,
    customer_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL,
    description TEXT,
    urgency public.urgency_level DEFAULT 'standard',
    job_status public.job_status DEFAULT 'pending',
    quoted_price NUMERIC(10,2),
    eta_minutes INTEGER,
    customer_confirmation BOOLEAN,
    provider_confirmation BOOLEAN,
    confirmation_round INTEGER DEFAULT 0,
    accepted_payment_methods TEXT DEFAULT 'cash,online',
    payment_method_used TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- App Config & Branding
CREATE TABLE public.app_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    setting_type TEXT DEFAULT 'text',
    description TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Multi-language Content (FAQ/ToS)
CREATE TABLE public.app_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type TEXT NOT NULL, -- 'faq', 'terms', 'privacy'
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  title_translations JSONB DEFAULT '{}'::jsonb,
  body_translations JSONB DEFAULT '{}'::jsonb,
  question_translations JSONB DEFAULT '{}'::jsonb,
  answer_translations JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Miscellaneous
CREATE TABLE public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT DEFAULT 'android',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, token)
);

CREATE TABLE public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_request_id UUID REFERENCES public.job_requests(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 3. FUNCTIONS & TRIGGERS ──────────────────────────────────

-- Profile creation upon auth.signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, phone, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer')::public.user_role
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Automatic Geo/Range Sync to Service Listings
CREATE OR REPLACE FUNCTION public.sync_provider_geo_to_services()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.provider_services
    SET geo_zone_id = NEW.selected_geo_zone_id,
        service_range_miles = NEW.service_range_miles
    WHERE provider_id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_provider_geo_update AFTER UPDATE OF selected_geo_zone_id, service_range_miles ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_provider_geo_to_services();

-- Role check helper
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT COALESCE(
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()),
    'customer'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- ─── 4. SEED DATA ─────────────────────────────────────────────

-- App Settings & Branding
INSERT INTO public.app_settings (setting_key, setting_value, setting_type) VALUES
('app_name', 'RoadRescue', 'text'),
('app_tagline', 'Instant Roadside Help', 'text'),
('primary_color', '#1A56DB', 'text'),
('secondary_color', '#7C3AED', 'text'),
('logo_url', 'https://images.unsplash.com/photo-1616432043562-3671ea2e5242?w=200', 'text'),
('distance_unit', 'mi', 'text'),
('commission_enabled', 'true', 'boolean'),
('commission_percent', '15', 'number'),
('online_payment_enabled', 'true', 'boolean'),
('cash_payment_enabled', 'true', 'boolean'),
('whatsapp_chat_enabled', 'true', 'boolean'),
('post_payment_screen_online', 'true', 'boolean'),
('post_payment_screen_cash', 'false', 'boolean'),
('default_language', 'en', 'text');

-- Cities
INSERT INTO public.cities (name, state) VALUES
('Cancún', 'Quintana Roo'), ('Playa del Carmen', 'Quintana Roo'), ('Tulum', 'Quintana Roo'), ('Mérida', 'Yucatán'), ('Valladolid', 'Yucatán');

-- Service Categories
INSERT INTO public.service_categories (name, icon_emoji, sort_order) VALUES
('Towing', '🛻', 1), ('Jump Start', '⚡', 2), ('Flat Tire', '🚗', 3), ('Lockout', '🔑', 4), ('Fuel Delivery', '⛽', 5);

-- Subscription Plans
INSERT INTO public.subscription_plans (name, price_monthly, trial_days, is_active, max_categories, max_radius_miles) VALUES
('Basic', 9.99, 14, true, 1, 25),
('Professional', 24.99, 14, true, 3, 50),
('Enterprise', 59.99, 30, true, 10, 100);

-- ─── 5. SECURITY & REAL-TIME ───────────────────────────────────

-- Enable Real-time Replication
ALTER TABLE public.job_requests REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.job_requests, public.app_settings;
  ELSE
    CREATE PUBLICATION supabase_realtime FOR TABLE public.job_requests, public.app_settings;
  END IF;
END $$;

-- Repair Permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;

-- Row Level Security (RLS)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read profiles" ON public.user_profiles FOR SELECT USING (true);
CREATE POLICY "Update own profile" ON public.user_profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE public.job_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read requests" ON public.job_requests FOR SELECT USING (true);
CREATE POLICY "Create requests" ON public.job_requests FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Update requests" ON public.job_requests FOR UPDATE USING (auth.uid() = customer_id OR auth.uid() = provider_id);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read settings" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Admin manage settings" ON public.app_settings FOR ALL USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read plans" ON public.subscription_plans FOR SELECT USING (true);
CREATE POLICY "Admin manage plans" ON public.subscription_plans FOR ALL USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

ALTER TABLE public.geo_zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read zones" ON public.geo_zones FOR SELECT USING (true);

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read cities" ON public.cities FOR SELECT USING (true);

ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read categories" ON public.service_categories FOR SELECT USING (true);

ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read provider services" ON public.provider_services FOR SELECT USING (true);
CREATE POLICY "Providers manage own services" ON public.provider_services FOR ALL USING (auth.uid() = provider_id);
