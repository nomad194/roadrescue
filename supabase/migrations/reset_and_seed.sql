-- ============================================================
-- RESET AND FRESH MIGRATION
-- WARNING: This drops all existing data and recreates schema
-- ============================================================

-- Drop existing tables (reverse order of dependencies)
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.job_requests CASCADE;
DROP TABLE IF EXISTS public.provider_services CASCADE;
DROP TABLE IF EXISTS public.provider_subscriptions CASCADE;
DROP TABLE IF EXISTS public.provider_payment_methods CASCADE;
DROP TABLE IF EXISTS public.payment_methods CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.cities CASCADE;
DROP TABLE IF EXISTS public.states CASCADE;
DROP TABLE IF EXISTS public.geo_zones CASCADE;
DROP TABLE IF EXISTS public.plans CASCADE;

-- Drop types
DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.job_status CASCADE;
DROP TYPE IF EXISTS public.urgency_level CASCADE;
DROP TYPE IF EXISTS public.notification_type CASCADE;
DROP TYPE IF EXISTS public.notification_status CASCADE;
DROP TYPE IF EXISTS public.plan_type CASCADE;

-- Create ENUM types
CREATE TYPE public.user_role AS ENUM ('customer', 'provider', 'admin');
CREATE TYPE public.job_status AS ENUM (
  'pending',
  'quoted',
  'accepted',
  'awaiting_confirmation',
  'confirmed',
  'en_route',
  'in_progress',
  'completed',
  'cancelled',
  'disputed',
  'awaiting_reconfirmation'
);
CREATE TYPE public.urgency_level AS ENUM ('urgent', 'standard', 'scheduled');
CREATE TYPE public.notification_type AS ENUM (
  'job_request',
  'quote_received',
  'quote_accepted',
  'provider_assigned',
  'job_confirmed',
  'status_update',
  'payment_received',
  'system'
);
CREATE TYPE public.notification_status AS ENUM ('pending', 'sent', 'read', 'archived');
CREATE TYPE public.plan_type AS ENUM ('basic', 'premium', 'enterprise');

-- ============================================================
-- CORE TABLES
-- ============================================================

-- States table
CREATE TABLE public.states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    country TEXT DEFAULT 'Mexico',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Cities table
CREATE TABLE public.cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    state TEXT NOT NULL,
    state_id UUID REFERENCES public.states(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(name, state_id)
);

-- Geo Zones table
CREATE TABLE public.geo_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'America/Cancun',
    radius_miles INTEGER DEFAULT 25,
    is_active BOOLEAN DEFAULT true,
    state_id UUID REFERENCES public.states(id) ON DELETE CASCADE,
    city_id UUID REFERENCES public.cities(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- User Profiles table
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    role public.user_role DEFAULT 'customer',
    avatar_url TEXT,
    address TEXT,
    address_lat FLOAT,
    address_lng FLOAT,
    selected_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL,
    selected_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL,
    selected_geo_zone_id UUID REFERENCES public.geo_zones(id) ON DELETE SET NULL,
    service_range_miles INTEGER DEFAULT 25,
    is_available BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    business_name TEXT,
    business_image_url TEXT,
    stripe_customer_id TEXT,
    stripe_account_id TEXT,
    notification_enabled BOOLEAN DEFAULT true,
    marketing_opt_in BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Job Requests table
CREATE TABLE public.job_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL,
    service_icon TEXT DEFAULT 'build',
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

-- Plans table
CREATE TABLE public.plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    stripe_price_id TEXT,
    stripe_product_id TEXT,
    type public.plan_type DEFAULT 'basic',
    monthly_price NUMERIC(10,2) NOT NULL,
    yearly_price NUMERIC(10,2),
    max_jobs INTEGER DEFAULT 10,
    commission_rate NUMERIC(5,2) DEFAULT 0.15,
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Provider Subscriptions table
CREATE TABLE public.provider_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.plans(id) ON DELETE SET NULL,
    stripe_subscription_id TEXT,
    status TEXT DEFAULT 'active',
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT false,
    jobs_used_this_period INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(provider_id)
);

-- Provider Services table
CREATE TABLE public.provider_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES public.service_categories(id) ON DELETE CASCADE,
    geo_zone_id UUID REFERENCES public.geo_zones(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    base_price NUMERIC(10,2) DEFAULT 0,
    distance_rules JSONB DEFAULT '[]'::jsonb,
    time_surcharges JSONB DEFAULT '[]'::jsonb,
    supported_vehicle_sizes JSONB DEFAULT '["sedan", "suv", "van", "pickup"]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Payment Methods table
CREATE TABLE public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT false,
    requires_setup BOOLEAN DEFAULT false,
    setup_instructions TEXT,
    display_order INTEGER DEFAULT 0,
    icon_name TEXT DEFAULT 'payment',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Provider Payment Methods table
CREATE TABLE public.provider_payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    payment_method_id UUID REFERENCES public.payment_methods(id) ON DELETE CASCADE,
    is_accepted BOOLEAN DEFAULT false,
    account_email TEXT,
    account_info JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(provider_id, payment_method_id)
);

-- App Settings table
CREATE TABLE public.app_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Notifications table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    type public.notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    status public.notification_status DEFAULT 'pending',
    related_entity_id UUID,
    action_taken BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_job_requests_customer ON public.job_requests(customer_id);
CREATE INDEX idx_job_requests_provider ON public.job_requests(provider_id);
CREATE INDEX idx_job_requests_status ON public.job_requests(job_status);
CREATE INDEX idx_job_requests_location ON public.job_requests(customer_lat, customer_lng);
CREATE INDEX idx_job_requests_city ON public.job_requests(customer_city_id);
CREATE INDEX idx_job_requests_state ON public.job_requests(customer_state_id);
CREATE INDEX idx_user_profiles_location ON public.user_profiles(address_lat, address_lng);
CREATE INDEX idx_user_profiles_state ON public.user_profiles(selected_state_id);
CREATE INDEX idx_user_profiles_city ON public.user_profiles(selected_city_id);
CREATE INDEX idx_cities_state ON public.cities(state_id);
CREATE INDEX idx_geo_zones_state ON public.geo_zones(state_id);
CREATE INDEX idx_geo_zones_city ON public.geo_zones(city_id);
CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_status ON public.notifications(status);
CREATE INDEX idx_provider_services_provider ON public.provider_services(provider_id);
CREATE INDEX idx_provider_subscriptions_provider ON public.provider_subscriptions(provider_id);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Seed States
INSERT INTO public.states (code, name, country) VALUES
('QR', 'Quintana Roo', 'Mexico'),
('YU', 'Yucatán', 'Mexico');

-- Seed Quintana Roo Cities (66 localities)
WITH state_qr AS (SELECT id FROM public.states WHERE code = 'QR')
INSERT INTO public.cities (name, state, state_id) VALUES
('Akumal', 'Quintana Roo', (SELECT id FROM state_qr)),
('Alfredo V. Bonfil', 'Quintana Roo', (SELECT id FROM state_qr)),
('Álvaro Obregón', 'Quintana Roo', (SELECT id FROM state_qr)),
('Bacalar', 'Quintana Roo', (SELECT id FROM state_qr)),
('Benito Juárez', 'Quintana Roo', (SELECT id FROM state_qr)),
('Cacao', 'Quintana Roo', (SELECT id FROM state_qr)),
('Calderitas', 'Quintana Roo', (SELECT id FROM state_qr)),
('Cancún', 'Quintana Roo', (SELECT id FROM state_qr)),
('Caobas', 'Quintana Roo', (SELECT id FROM state_qr)),
('Carlos A. Madrazo', 'Quintana Roo', (SELECT id FROM state_qr)),
('Chetumal', 'Quintana Roo', (SELECT id FROM state_qr)),
('Chiquilá', 'Quintana Roo', (SELECT id FROM state_qr)),
('Chunhuhub', 'Quintana Roo', (SELECT id FROM state_qr)),
('Ciudad Chemuyil', 'Quintana Roo', (SELECT id FROM state_qr)),
('Coba', 'Quintana Roo', (SELECT id FROM state_qr)),
('Cocoyol', 'Quintana Roo', (SELECT id FROM state_qr)),
('Cozumel', 'Quintana Roo', (SELECT id FROM state_qr)),
('Dziuche', 'Quintana Roo', (SELECT id FROM state_qr)),
('Dzula', 'Quintana Roo', (SELECT id FROM state_qr)),
('El Tintal', 'Quintana Roo', (SELECT id FROM state_qr)),
('Felipe Carrillo Puerto', 'Quintana Roo', (SELECT id FROM state_qr)),
('Huay Max', 'Quintana Roo', (SELECT id FROM state_qr)),
('Huay-Pix', 'Quintana Roo', (SELECT id FROM state_qr)),
('Ignacio Zaragoza', 'Quintana Roo', (SELECT id FROM state_qr)),
('Isla Holbox', 'Quintana Roo', (SELECT id FROM state_qr)),
('Isla Mujeres', 'Quintana Roo', (SELECT id FROM state_qr)),
('Javier Rojo Gómez', 'Quintana Roo', (SELECT id FROM state_qr)),
('José María Morelos', 'Quintana Roo', (SELECT id FROM state_qr)),
('Jose Narciso Rovirosa', 'Quintana Roo', (SELECT id FROM state_qr)),
('Juan Sarabia', 'Quintana Roo', (SELECT id FROM state_qr)),
('Kancabchén', 'Quintana Roo', (SELECT id FROM state_qr)),
('Kantunilkín', 'Quintana Roo', (SELECT id FROM state_qr)),
('La Presumida', 'Quintana Roo', (SELECT id FROM state_qr)),
('La Unión', 'Quintana Roo', (SELECT id FROM state_qr)),
('Lázaro Cárdenas', 'Quintana Roo', (SELECT id FROM state_qr)),
('Leona Vicario', 'Quintana Roo', (SELECT id FROM state_qr)),
('Los Divorciados', 'Quintana Roo', (SELECT id FROM state_qr)),
('Maya Balam', 'Quintana Roo', (SELECT id FROM state_qr)),
('Morocoy', 'Quintana Roo', (SELECT id FROM state_qr)),
('Nicolás Bravo', 'Quintana Roo', (SELECT id FROM state_qr)),
('Nuevo Xcán', 'Quintana Roo', (SELECT id FROM state_qr)),
('Othón P. Blanco', 'Quintana Roo', (SELECT id FROM state_qr)),
('Playa del Carmen', 'Quintana Roo', (SELECT id FROM state_qr)),
('Polyuc', 'Quintana Roo', (SELECT id FROM state_qr)),
('Presidente Juárez', 'Quintana Roo', (SELECT id FROM state_qr)),
('Pucté', 'Quintana Roo', (SELECT id FROM state_qr)),
('Puerto Aventuras', 'Quintana Roo', (SELECT id FROM state_qr)),
('Puerto Morelos', 'Quintana Roo', (SELECT id FROM state_qr)),
('Saban', 'Quintana Roo', (SELECT id FROM state_qr)),
('Sabidos', 'Quintana Roo', (SELECT id FROM state_qr)),
('San Angel', 'Quintana Roo', (SELECT id FROM state_qr)),
('Santa Rosa Segundo', 'Quintana Roo', (SELECT id FROM state_qr)),
('Señor', 'Quintana Roo', (SELECT id FROM state_qr)),
('Sergio Butrón Casas', 'Quintana Roo', (SELECT id FROM state_qr)),
('Solidaridad', 'Quintana Roo', (SELECT id FROM state_qr)),
('Subteniente López', 'Quintana Roo', (SELECT id FROM state_qr)),
('Tepich', 'Quintana Roo', (SELECT id FROM state_qr)),
('Tihosuco', 'Quintana Roo', (SELECT id FROM state_qr)),
('Tulum', 'Quintana Roo', (SELECT id FROM state_qr)),
('Ucum', 'Quintana Roo', (SELECT id FROM state_qr)),
('X Cabil', 'Quintana Roo', (SELECT id FROM state_qr)),
('X-Hazil Sur', 'Quintana Roo', (SELECT id FROM state_qr)),
('X-pichil', 'Quintana Roo', (SELECT id FROM state_qr)),
('Xul-Ha', 'Quintana Roo', (SELECT id FROM state_qr)),
('Zacalaca', 'Quintana Roo', (SELECT id FROM state_qr));

-- Seed Yucatán Municipalities (major cities - 25 for now)
WITH state_yu AS (SELECT id FROM public.states WHERE code = 'YU')
INSERT INTO public.cities (name, state, state_id) VALUES
('Mérida', 'Yucatán', (SELECT id FROM state_yu)),
('Valladolid', 'Yucatán', (SELECT id FROM state_yu)),
('Progreso', 'Yucatán', (SELECT id FROM state_yu)),
('Tizimín', 'Yucatán', (SELECT id FROM state_yu)),
('Umán', 'Yucatán', (SELECT id FROM state_yu)),
('Kanasín', 'Yucatán', (SELECT id FROM state_yu)),
('Izamal', 'Yucatán', (SELECT id FROM state_yu)),
('Motul', 'Yucatán', (SELECT id FROM state_yu)),
('Tekax', 'Yucatán', (SELECT id FROM state_yu)),
('Ticul', 'Yucatán', (SELECT id FROM state_yu)),
('Oxkutzcab', 'Yucatán', (SELECT id FROM state_yu)),
('Maxcanú', 'Yucatán', (SELECT id FROM state_yu)),
('Hunucmá', 'Yucatán', (SELECT id FROM state_yu)),
('Acanceh', 'Yucatán', (SELECT id FROM state_yu)),
('Espita', 'Yucatán', (SELECT id FROM state_yu)),
('Temozón', 'Yucatán', (SELECT id FROM state_yu)),
('Río Lagartos', 'Yucatán', (SELECT id FROM state_yu)),
('Panabá', 'Yucatán', (SELECT id FROM state_yu)),
('Sinanché', 'Yucatán', (SELECT id FROM state_yu)),
('Dzidzantún', 'Yucatán', (SELECT id FROM state_yu)),
('Telchac Pueblo', 'Yucatán', (SELECT id FROM state_yu)),
('Seyé', 'Yucatán', (SELECT id FROM state_yu)),
('Sotuta', 'Yucatán', (SELECT id FROM state_yu)),
('Homún', 'Yucatán', (SELECT id FROM state_yu)),
('Hocabá', 'Yucatán', (SELECT id FROM state_yu));

-- Seed Payment Methods
INSERT INTO public.payment_methods (code, name, description, is_active, is_online, display_order, icon_name) VALUES
('cash', 'Cash', 'Pay with cash on service completion', true, false, 1, 'payments'),
('stripe', 'Credit/Debit Card', 'Secure online payment via Stripe', true, true, 2, 'credit_card');

-- Seed App Settings
INSERT INTO public.app_settings (setting_key, setting_value, description) VALUES
('online_payment_enabled', 'true', 'Enable online payments globally'),
('cash_payment_enabled', 'true', 'Enable cash payments globally'),
('default_language', 'en', 'Default application language');

-- Seed Plans
INSERT INTO public.plans (name, type, monthly_price, yearly_price, max_jobs, commission_rate, features, display_order) VALUES
('Basic', 'basic', 29.99, 299.99, 10, 0.15, '["Up to 10 jobs/month", "15% commission", "Standard support"]'::jsonb, 1),
('Premium', 'premium', 79.99, 799.99, 50, 0.10, '["Up to 50 jobs/month", "10% commission", "Priority support", "Featured profile"]'::jsonb, 2),
('Enterprise', 'enterprise', 199.99, 1999.99, 999999, 0.05, '["Unlimited jobs", "5% commission", "24/7 support", "Custom branding"]'::jsonb, 3);

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================

-- Function to get cities by state
CREATE OR REPLACE FUNCTION public.get_cities_by_state(p_state_id UUID)
RETURNS SETOF public.cities
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.cities
    WHERE state_id = p_state_id
    ORDER BY name;
END;
$$;

-- Function to get jobs for provider (by geo zone + range)
CREATE OR REPLACE FUNCTION public.get_jobs_for_provider(
    p_provider_id UUID,
    p_state_id UUID,
    p_city_id UUID,
    p_provider_lat FLOAT,
    p_provider_lng FLOAT,
    p_range_miles INTEGER
)
RETURNS SETOF public.job_requests
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT jr.*
    FROM public.job_requests jr
    JOIN public.user_profiles customer ON jr.customer_id = customer.id
    WHERE jr.job_status = 'pending'
    AND (
        (jr.customer_state_id = p_state_id AND jr.customer_city_id = p_city_id)
        OR
        (jr.customer_lat IS NOT NULL AND jr.customer_lng IS NOT NULL
         AND (6371 * acos(
             cos(radians(p_provider_lat)) * cos(radians(jr.customer_lat)) *
             cos(radians(jr.customer_lng) - radians(p_provider_lng)) +
             sin(radians(p_provider_lat)) * sin(radians(jr.customer_lat))
         ) / 1.609344) <= p_range_miles)
    );
END;
$$;

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE public.states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geo_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- States policies
CREATE POLICY "states_select_all" ON public.states FOR SELECT TO authenticated USING (true);
CREATE POLICY "states_admin_all" ON public.states FOR ALL TO authenticated 
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- Cities policies
CREATE POLICY "cities_select_all" ON public.cities FOR SELECT TO authenticated USING (true);
CREATE POLICY "cities_admin_all" ON public.cities FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- Geo Zones policies
CREATE POLICY "geo_zones_select_all" ON public.geo_zones FOR SELECT TO authenticated USING (true);
CREATE POLICY "geo_zones_admin_all" ON public.geo_zones FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- User Profiles policies
CREATE POLICY "user_profiles_self" ON public.user_profiles FOR ALL TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "user_profiles_admin" ON public.user_profiles FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- Job Requests policies
CREATE POLICY "job_requests_customer" ON public.job_requests FOR ALL TO authenticated
USING (customer_id = auth.uid())
WITH CHECK (customer_id = auth.uid());

CREATE POLICY "job_requests_provider" ON public.job_requests FOR ALL TO authenticated
USING (provider_id = auth.uid() OR auth.jwt() ->> 'role' = 'admin');

-- Notifications policies
CREATE POLICY "notifications_self" ON public.notifications FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Plans policies (read-only for all, admin for write)
CREATE POLICY "plans_select_all" ON public.plans FOR SELECT TO authenticated USING (true);
CREATE POLICY "plans_admin_all" ON public.plans FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- Payment Methods policies
CREATE POLICY "payment_methods_select_all" ON public.payment_methods FOR SELECT TO authenticated USING (true);
CREATE POLICY "payment_methods_admin_all" ON public.payment_methods FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- App Settings policies (read-only for all, admin for write)
CREATE POLICY "app_settings_select_all" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_settings_admin_all" ON public.app_settings FOR ALL TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

-- ============================================================
-- REALTIME ENABLEMENT
-- ============================================================

-- Enable realtime for job_requests
BEGIN;
  -- Drop if exists
  DROP PUBLICATION IF EXISTS supabase_realtime;
  -- Create publication for realtime
  CREATE PUBLICATION supabase_realtime;
  -- Add tables to publication
  ALTER PUBLICATION supabase_realtime ADD TABLE public.job_requests;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
COMMIT;

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================
