# Fix Provider Job Discovery and Role Switching

This plan addresses two critical issues:
1. Providers cannot see or accept new (unassigned) job requests due to restrictive RLS policies.
2. Users cannot switch between "Provider" and "Driver" (customer) views because the `RouteGuard` strictly enforces a single role per screen.

## Proposed Changes

### Supabase Migrations

#### [20260520000004_fix_provider_access.sql](file:///C:/automigoapp/roadrescue/supabase/migrations/20260520000004_fix_provider_access.sql)

- Replace the `SELECT` policy for `job_requests` to allow providers to see unassigned `pending` requests.
- Replace the `UPDATE` policy for `job_requests` to allow providers to update unassigned requests (to assign themselves).

```sql
-- 1. Fix SELECT policy for job_requests
DROP POLICY IF EXISTS "Read own job requests" ON public.job_requests;
DROP POLICY IF EXISTS "Read requests" ON public.job_requests;

CREATE POLICY "Read own or pending job requests" ON public.job_requests
  FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR provider_id = auth.uid()
    OR (job_status = 'pending' AND provider_id IS NULL AND get_user_role() = 'provider')
    OR get_user_role() = 'admin'
  );

-- 2. Fix UPDATE policy for job_requests
DROP POLICY IF EXISTS "Update requests" ON public.job_requests;

CREATE POLICY "Update own or unassigned job requests" ON public.job_requests
  FOR UPDATE TO authenticated
  USING (
    customer_id = auth.uid()
    OR provider_id = auth.uid()
    OR (provider_id IS NULL AND get_user_role() = 'provider')
    OR get_user_role() = 'admin'
  )
  WITH CHECK (
    customer_id = auth.uid()
    OR provider_id = auth.uid()
    OR (provider_id = auth.uid() AND get_user_role() = 'provider')
    OR get_user_role() = 'admin'
  );
```

---

### App Navigation

#### [route_guard.dart](file:///C:/automigoapp/roadrescue/lib/routes/route_guard.dart)

- Update `_routeRoles` to allow both `customer` and `provider` roles to access both driver and provider screens. This enables the "Switch" functionality in the app headers.
- Include `admin` in all routes for full visibility.

```dart
const Map<String, List<String>?> _routeRoles = {
  AppRoutes.initial: null,
  AppRoutes.signUpLoginScreen: null,
  AppRoutes.faqTosScreen: null,
  AppRoutes.serviceRequestScreen: ['customer', 'provider', 'admin'],
  AppRoutes.customerProfileScreen: ['customer', 'provider', 'admin'],
  AppRoutes.serviceHistoryScreen: ['customer', 'provider', 'admin'],
  AppRoutes.paymentScreen: ['customer', 'provider', 'admin'],
  AppRoutes.postPaymentScreen: ['customer', 'provider', 'admin'],
  AppRoutes.jobRequestsScreen: ['customer', 'provider', 'admin'],
  AppRoutes.providerProfileScreen: ['customer', 'provider', 'admin'],
  AppRoutes.adminDashboardScreen: ['admin'],
};
```

## Verification Plan

### Manual Verification
- **RLS**: Review the SQL to ensure `provider_id IS NULL` check is correct and restricted to the `provider` role.
- **Switching**: Verify that a user logged in as a `provider` can navigate to the `serviceRequestScreen` (Driver view) and back to `jobRequestsScreen` without being redirected by the `RouteGuard`.
- **Switching**: Verify that a user logged in as a `customer` can similarly navigate between both views.
