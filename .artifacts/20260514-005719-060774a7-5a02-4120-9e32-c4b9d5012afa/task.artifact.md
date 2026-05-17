# Task: Provider Vehicle Support & Request Filtering

Allow providers to select supported vehicle sizes per category and ensure they only receive jobs for active categories.

- [/] Research and Planning
    - [x] Audit provider dashboard logic
    - [x] Create implementation plan
- [ ] Backend Implementation
    - [ ] Update `SupabaseService.getProviderJobRequests` with category filtering
- [ ] Provider UI Implementation
    - [ ] Update `_ServicePricing` and state in `JobRequestsScreen`
    - [ ] Add vehicle size checklist to `_PricingEditorSheet`
    - [ ] Update persistence and loading logic in `JobRequestsScreen`
- [ ] Verification
    - [ ] Verify category-based job filtering
    - [ ] Final `flutter analyze` pass
