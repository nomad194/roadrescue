# Provider Service Filtering & Vehicle Support Plan

Enable Providers to select supported vehicle sizes per category and enforce strict category-based request filtering.

## User Review Required

- **Database Column**: Ensure the column `supported_vehicle_sizes` (JSONB) exists in the `provider_services` table. If not, run:
  ```sql
  ALTER TABLE public.provider_services ADD COLUMN IF NOT EXISTS supported_vehicle_sizes JSONB DEFAULT '[]'::jsonb;
  ```
- **Job Filtering**: Providers will ONLY see job requests for categories they have enabled in their dashboard.

## Proposed Changes

### Supabase Service

#### [supabase_service.dart](file:///C:/automigoapp/roadrescue/lib/services/supabase_service.dart)
- Update `getProviderJobRequests` to accept a list of category names to filter requests at the query level.

---

### Provider Dashboard

#### [job_requests_screen.dart](file:///C:/automigoapp/roadrescue/lib/presentation/job_requests_screen/job_requests_screen.dart)
- Update `_ServicePricing` data class to include `supportedVehicleSizes`.
- **Pricing Editor Sheet**:
    - Add a checklist/grid for the provider to toggle which sizes they support (based on the category's enabled sizes).
- **Save Logic**: Update `_saveServices` to persist `supported_vehicle_sizes`.
- **Filtering**: Modify `_loadJobs` to fetch active categories first, then filter the job query.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no issues.

### Manual Verification
1. **Setup**: Enable "Towing" category as a provider.
2. **Setup**: In the "Towing" pricing editor, select only "Sedan" and "SUV" as supported.
3. **Verify Filtering**: As a customer, request "Fuel Delivery". The provider should NOT see this job.
4. **Verify Filtering**: As a customer, request "Towing". The provider SHOULD see this job.
5. **Verify Persistence**: Close and reopen the Provider Dashboard; ensure the selected vehicle sizes are still checked in the editor.
