/// Shared application constants that should eventually come from database
/// but are centralized here for maintainability
class AppConstants {
  // Vehicle size options - used across customer, provider, and admin screens
  // These should match the database service_categories.vehicle_sizes values
  static const List<Map<String, dynamic>> vehicleSizeOptions = [
    {
      'id': 'motorcycle',
      'label': 'Motorcycle',
      'emoji': '🏍️',
      'imageUrl': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=120&h=80&fit=crop',
    },
    {
      'id': 'sedan',
      'label': 'Sedan / Car',
      'emoji': '🚗',
      'imageUrl': 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=120&h=80&fit=crop',
    },
    {
      'id': 'suv',
      'label': 'SUV / Crossover',
      'emoji': '🚙',
      'imageUrl': 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=120&h=80&fit=crop',
    },
    {
      'id': 'pickup',
      'label': 'Pickup Truck',
      'emoji': '🛻',
      'imageUrl': 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=120&h=80&fit=crop',
    },
    {
      'id': 'van',
      'label': 'Van / Minivan',
      'emoji': '🚐',
      'imageUrl': 'https://images.unsplash.com/photo-1566008885218-90acd5028ed6?w=120&h=80&fit=crop',
    },
    {
      'id': 'large_truck',
      'label': 'Large Truck',
      'emoji': '🚛',
      'imageUrl': 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=120&h=80&fit=crop',
    },
  ];

  // Default values - should be loaded from app_settings table
  static const double defaultServiceRangeMiles = 25.0;
  static const int defaultMaxCategories = 1;
  static const int defaultMaxRadiusMiles = 25;
  static const int defaultTrialDays = 0;
  static const int defaultDiscountPercent = 0;
  static const String defaultTimezone = 'America/Cancun';

  // Free plan limits when provider has no subscription
  static const Map<String, dynamic> freePlanLimits = {
    'max_categories': 1,
    'can_set_distance_surcharges': false,
    'can_use_after_hours': false,
    'max_radius_miles': 25,
  };
}
