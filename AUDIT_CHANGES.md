# RoadRescue Database Audit - Changes Summary

## Summary
All hardcoded values have been centralized into `lib/config/app_constants.dart` for maintainability and consistency across the app.

## Changes Made

### 1. Created Shared Constants File
**File:** `lib/config/app_constants.dart`
- Centralized vehicle size options (6 vehicles with emojis and images)
- Default values for service range (25.0 miles)
- Default subscription limits (max_categories: 1)
- Default plan values (trial days: 0, discount: 0, max radius: 25)
- Default timezone (America/Cancun)
- Free plan fallback limits for unsubscribed providers

### 2. Updated Service Request Screen
**File:** `lib/presentation/service_request_screen/service_request_screen.dart`
- Replaced hardcoded vehicle list with `AppConstants.vehicleSizeOptions`

### 3. Updated Job Requests Screen  
**File:** `lib/presentation/job_requests_screen/job_requests_screen.dart`
- Replaced hardcoded `25.0` service range default with `AppConstants.defaultServiceRangeMiles`
- Replaced hardcoded subscription fallback limits with `AppConstants.freePlanLimits`
- Replaced hardcoded vehicle list in `_PricingEditorSheet` with shared constants

### 4. Updated Supabase Service
**File:** `lib/services/supabase_service.dart`
- Replaced hardcoded `25.0` service range with `AppConstants.defaultServiceRangeMiles`

### 5. Updated Admin Categories Widget
**File:** `lib/presentation/admin_dashboard_screen/widgets/admin_categories_widget.dart`
- Replaced hardcoded vehicle list with `AppConstants.vehicleSizeOptions`

### 6. Updated Admin Payments Widget
**File:** `lib/presentation/admin_dashboard_screen/widgets/admin_payments_widget.dart`
- Replaced hardcoded default values (25, 2, 0) with `AppConstants` values

### 7. Updated Admin Geo Zones Widget
**File:** `lib/presentation/admin_dashboard_screen/widgets/admin_geo_zones_widget.dart`
- Replaced hardcoded timezone with `AppConstants.defaultTimezone`

### 8. Updated Admin App Config Widget
**File:** `lib/presentation/admin_dashboard_screen/widgets/admin_app_config_widget.dart`
- Removed hardcoded 'RoadRescue' default - now loads from database only

## Testing Recommendations

1. **Provider Flow:**
   - Toggle service categories on/off
   - Edit pricing with multiple vehicles selected
   - Verify auto-save works correctly
   - Verify data persists after screen reload

2. **Customer Flow:**
   - Create service request
   - Select vehicle size
   - Verify all 6 vehicle options appear correctly

3. **Admin Flow:**
   - Create subscription plan - verify defaults load from constants
   - Manage service categories - verify vehicle images/emojis show
   - Create geo zone - verify default timezone loads

## Remaining Hardcoded Values (Acceptable)

- **Theme colors** (`lib/theme/app_theme.dart`) - Brand colors are intentionally hardcoded
- **Localization strings** (`lib/services/localization_service.dart`) - Translation strings are acceptable as hardcoded
- **Route names** (`lib/routes/app_routes.dart`) - Navigation routes are intentionally hardcoded

## Future Improvements

To fully database-drive these values, consider:

1. Create `app_settings` table entries for:
   - `default_service_range_miles`
   - `default_max_categories`
   - `default_trial_days`
   - `default_timezone`

2. Fetch these at app startup and cache them

3. Add admin UI to edit these defaults

4. Move vehicle size options to `service_categories.vehicle_sizes` and fetch dynamically
