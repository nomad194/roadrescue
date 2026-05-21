-- Tighten RLS and revoke excessive anon grants from master_schema.

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON public.cities TO anon, authenticated;
GRANT SELECT ON public.geo_zones TO anon, authenticated;
GRANT SELECT ON public.service_categories TO anon, authenticated;
GRANT SELECT ON public.subscription_plans TO anon, authenticated;
GRANT SELECT ON public.app_settings TO anon, authenticated;
GRANT SELECT ON public.app_content TO anon, authenticated;
GRANT SELECT ON public.provider_services TO anon, authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

-- job_requests: replace open read with scoped access
DROP POLICY IF EXISTS "Read requests" ON public.job_requests;
CREATE POLICY "Read own job requests" ON public.job_requests
  FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR provider_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- payments policies
DROP POLICY IF EXISTS "users_view_own_payments" ON public.payments;
CREATE POLICY "users_view_own_payments" ON public.payments
  FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR provider_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "customers_create_payments" ON public.payments;
CREATE POLICY "customers_create_payments" ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "service_role_manage_payments" ON public.payments;
CREATE POLICY "service_role_manage_payments" ON public.payments
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "admin_manage_payments" ON public.payments;
CREATE POLICY "admin_manage_payments" ON public.payments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- provider_subscriptions policies
DROP POLICY IF EXISTS "providers_view_own_subscriptions" ON public.provider_subscriptions;
CREATE POLICY "providers_view_own_subscriptions" ON public.provider_subscriptions
  FOR SELECT TO authenticated
  USING (
    provider_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "providers_manage_own_subscriptions" ON public.provider_subscriptions;
CREATE POLICY "providers_manage_own_subscriptions" ON public.provider_subscriptions
  FOR ALL TO authenticated
  USING (provider_id = auth.uid())
  WITH CHECK (provider_id = auth.uid());

DROP POLICY IF EXISTS "admin_manage_provider_subscriptions" ON public.provider_subscriptions;
CREATE POLICY "admin_manage_provider_subscriptions" ON public.provider_subscriptions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
