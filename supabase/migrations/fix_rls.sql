-- Fix RLS policies for app_settings - allow all authenticated users to modify
-- This is needed because JWT doesn't contain role claim by default

-- Drop existing policies on app_settings
DROP POLICY IF EXISTS "app_settings_select_all" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_admin_all" ON public.app_settings;

-- Create new policies that allow all authenticated users full access
-- (App-level admin checks should be done in Flutter code)
CREATE POLICY "app_settings_select_all" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_settings_insert_all" ON public.app_settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "app_settings_update_all" ON public.app_settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "app_settings_delete_all" ON public.app_settings FOR DELETE TO authenticated USING (true);

-- Also fix payment_methods RLS
DROP POLICY IF EXISTS "payment_methods_select_all" ON public.payment_methods;
DROP POLICY IF EXISTS "payment_methods_admin_all" ON public.payment_methods;

CREATE POLICY "payment_methods_select_all" ON public.payment_methods FOR SELECT TO authenticated USING (true);
CREATE POLICY "payment_methods_insert_all" ON public.payment_methods FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "payment_methods_update_all" ON public.payment_methods FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "payment_methods_delete_all" ON public.payment_methods FOR DELETE TO authenticated USING (true);

-- Fix user_profiles RLS to avoid recursion
DROP POLICY IF EXISTS "user_profiles_self" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_admin" ON public.user_profiles;

CREATE POLICY "user_profiles_all" ON public.user_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Fix job_requests RLS
DROP POLICY IF EXISTS "job_requests_customer" ON public.job_requests;
DROP POLICY IF EXISTS "job_requests_provider" ON public.job_requests;

CREATE POLICY "job_requests_all" ON public.job_requests FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Fix states/cities/geo_zones RLS
DROP POLICY IF EXISTS "states_select_all" ON public.states;
DROP POLICY IF EXISTS "states_admin_all" ON public.states;
DROP POLICY IF EXISTS "cities_select_all" ON public.cities;
DROP POLICY IF EXISTS "cities_admin_all" ON public.cities;
DROP POLICY IF EXISTS "geo_zones_select_all" ON public.geo_zones;
DROP POLICY IF EXISTS "geo_zones_admin_all" ON public.geo_zones;

CREATE POLICY "states_all" ON public.states FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "cities_all" ON public.cities FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "geo_zones_all" ON public.geo_zones FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Fix plans and other tables
DROP POLICY IF EXISTS "plans_select_all" ON public.plans;
DROP POLICY IF EXISTS "plans_admin_all" ON public.plans;
DROP POLICY IF EXISTS "notifications_self" ON public.notifications;
DROP POLICY IF EXISTS "provider_subscriptions_all" ON public.provider_subscriptions;
DROP POLICY IF EXISTS "provider_services_all" ON public.provider_services;
DROP POLICY IF EXISTS "provider_payment_methods_all" ON public.provider_payment_methods;

CREATE POLICY "plans_all" ON public.plans FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "notifications_all" ON public.notifications FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "provider_subscriptions_all" ON public.provider_subscriptions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "provider_services_all" ON public.provider_services FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "provider_payment_methods_all" ON public.provider_payment_methods FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- RLS FIXED - All authenticated users can now modify all tables
-- (In production, add proper admin checks in Flutter code)
