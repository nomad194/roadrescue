-- ============================================================
-- RoadRescue: Auth + Real-time Database Migration
-- Tables: user_profiles, job_requests, bookings
-- ============================================================

-- 1. TYPES
DROP TYPE IF EXISTS public.user_role CASCADE;
CREATE TYPE public.user_role AS ENUM ('customer', 'provider', 'admin');

DROP TYPE IF EXISTS public.job_status CASCADE;
CREATE TYPE public.job_status AS ENUM ('pending', 'quoted', 'accepted', 'confirmed', 'in_progress', 'completed', 'cancelled');

DROP TYPE IF EXISTS public.urgency_level CASCADE;
CREATE TYPE public.urgency_level AS ENUM ('standard', 'urgent');

-- 2. CORE TABLES

-- user_profiles: linked to auth.users via trigger
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    phone TEXT DEFAULT '',
    role public.user_role NOT NULL DEFAULT 'customer'::public.user_role,
    avatar_url TEXT DEFAULT '',
    business_name TEXT DEFAULT '',
    service_range_miles INTEGER DEFAULT 25,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- job_requests: submitted by customers, visible to providers
CREATE TABLE IF NOT EXISTS public.job_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    service_type TEXT NOT NULL,
    service_icon TEXT NOT NULL DEFAULT 'build',
    vehicle_size TEXT DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    description TEXT DEFAULT '',
    urgency public.urgency_level NOT NULL DEFAULT 'standard'::public.urgency_level,
    job_status public.job_status NOT NULL DEFAULT 'pending'::public.job_status,
    provider_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    quoted_price DECIMAL(10,2),
    eta_minutes INTEGER,
    provider_notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- bookings: confirmed engagements between customer and provider
CREATE TABLE IF NOT EXISTS public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_request_id UUID NOT NULL REFERENCES public.job_requests(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    final_price DECIMAL(10,2),
    booking_status public.job_status NOT NULL DEFAULT 'confirmed'::public.job_status,
    customer_rating INTEGER,
    customer_review TEXT DEFAULT '',
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. INDEXES
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_job_requests_customer_id ON public.job_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_job_requests_provider_id ON public.job_requests(provider_id);
CREATE INDEX IF NOT EXISTS idx_job_requests_status ON public.job_requests(job_status);
CREATE INDEX IF NOT EXISTS idx_job_requests_created_at ON public.job_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_id ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_id ON public.bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_bookings_job_request_id ON public.bookings(job_request_id);

-- 4. FUNCTIONS (must be before RLS policies)

-- Auto-create user_profiles on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, phone, role, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer')::public.user_role,
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Role check helper (reads from auth metadata, no recursion risk)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT COALESCE(
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()),
    'customer'
);
$$;

-- 5. ENABLE RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- 6. RLS POLICIES

-- user_profiles: users manage their own profile; admins see all
DROP POLICY IF EXISTS "users_manage_own_profile" ON public.user_profiles;
CREATE POLICY "users_manage_own_profile"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "providers_view_customer_profiles" ON public.user_profiles;
CREATE POLICY "providers_view_customer_profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (true);

-- job_requests: customers manage their own; providers can view all pending/quoted and update assigned ones
DROP POLICY IF EXISTS "customers_manage_own_requests" ON public.job_requests;
CREATE POLICY "customers_manage_own_requests"
ON public.job_requests
FOR ALL
TO authenticated
USING (customer_id = auth.uid())
WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "providers_view_all_requests" ON public.job_requests;
CREATE POLICY "providers_view_all_requests"
ON public.job_requests
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "providers_update_assigned_requests" ON public.job_requests;
CREATE POLICY "providers_update_assigned_requests"
ON public.job_requests
FOR UPDATE
TO authenticated
USING (provider_id = auth.uid() OR provider_id IS NULL)
WITH CHECK (true);

-- bookings: customers and providers see their own bookings
DROP POLICY IF EXISTS "users_view_own_bookings" ON public.bookings;
CREATE POLICY "users_view_own_bookings"
ON public.bookings
FOR SELECT
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid());

DROP POLICY IF EXISTS "providers_create_bookings" ON public.bookings;
CREATE POLICY "providers_create_bookings"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (provider_id = auth.uid());

DROP POLICY IF EXISTS "users_update_own_bookings" ON public.bookings;
CREATE POLICY "users_update_own_bookings"
ON public.bookings
FOR UPDATE
TO authenticated
USING (customer_id = auth.uid() OR provider_id = auth.uid())
WITH CHECK (customer_id = auth.uid() OR provider_id = auth.uid());

-- 7. TRIGGERS
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS set_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER set_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_job_requests_updated_at ON public.job_requests;
CREATE TRIGGER set_job_requests_updated_at
    BEFORE UPDATE ON public.job_requests
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_bookings_updated_at ON public.bookings;
CREATE TRIGGER set_bookings_updated_at
    BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 8. MOCK DATA (demo users for testing)
DO $$
DECLARE
    customer_uuid UUID := gen_random_uuid();
    provider_uuid UUID := gen_random_uuid();
    admin_uuid UUID := gen_random_uuid();
    job_uuid UUID := gen_random_uuid();
BEGIN
    -- Create demo auth users (trigger will create user_profiles automatically)
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (customer_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'demo.driver@roadrescue.com', crypt('Driver@2026', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'Marcus Johnson', 'phone', '+15125550174', 'role', 'customer'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (provider_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'provider.demo@roadrescue.com', crypt('Provider@2026', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'Carlos Rivera', 'phone', '+15125550291', 'role', 'provider'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@roadrescue.com', crypt('Admin@2026', gen_salt('bf', 10)), now(), now(), now(),
         jsonb_build_object('full_name', 'Road Rescue Admin', 'role', 'admin'),
         jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null)
    ON CONFLICT (id) DO NOTHING;

    -- Update provider profile with business info (after trigger creates it)
    UPDATE public.user_profiles
    SET business_name = 'Rivera Road Rescue', service_range_miles = 30, is_available = true
    WHERE id = provider_uuid;

    -- Create a sample job request from the customer
    INSERT INTO public.job_requests (
        id, customer_id, service_type, service_icon, vehicle_size,
        address, description, urgency, job_status, created_at
    ) VALUES (
        job_uuid, customer_uuid, 'Towing', 'local_shipping', 'sedan',
        '4721 Maple Ave, Austin, TX',
        '2019 Honda Civic will not start, needs tow to nearest Honda service center.',
        'standard'::public.urgency_level, 'pending'::public.job_status, now() - interval '5 minutes'
    ) ON CONFLICT (id) DO NOTHING;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mock data insertion failed: %', SQLERRM;
END $$;
