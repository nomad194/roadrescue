# Tasks

- [x] Research why providers are not receiving requests
- [x] Identify RLS policy as the root cause
- [x] Research why role switching stopped working
- [x] Identify `RouteGuard` as the cause for switching failure
- [/] Fix RLS and Route Guard
	- [ ] Create migration `20260520000004_fix_provider_access.sql`
	- [ ] Update `route_guard.dart` to allow switching
- [ ] Verify the fix
