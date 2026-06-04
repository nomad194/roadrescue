import 'dart:convert';
import '../services/localization_service.dart';

/// Shared application constants that should eventually come from database
/// but are centralized here for maintainability
class AppConstants {
  // Mapping of vehicle id → localization key
  static const Map<String, String> vehicleSizeLabelKeys = {
    'motorcycle': 'vehicle_size_motorcycle',
    'sedan': 'vehicle_size_sedan',
    'suv': 'vehicle_size_suv',
    'pickup': 'vehicle_size_pickup',
    'van': 'vehicle_size_van',
    'large_truck': 'vehicle_size_large_truck',
  };

  /// Admin-entered vehicle name translations loaded from app_settings.
  /// Shape: { "motorcycle": { "en": "Motorcycle", "es": "Motocicleta" }, ... }
  static Map<String, Map<String, String>> _vehicleSizeTranslations = {};

  /// Load admin-entered vehicle size translations from a raw JSON string.
  /// Called from main.dart after fetching from DB.
  static void setVehicleSizeTranslations(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = Map<String, dynamic>.from(json.decode(raw) as Map);
      _vehicleSizeTranslations = {};
      for (final entry in decoded.entries) {
        _vehicleSizeTranslations[entry.key] = Map<String, String>.from(
          (entry.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
    } catch (_) {}
  }

  /// Get the localized label for a vehicle size id.
  /// Priority: 1) admin DB translations, 2) language file keys, 3) hardcoded English.
  static String getVehicleSizeLabel(String vehicleId) {
    // 1. Check admin-entered DB translations first
    final lang = LocalizationService.instance.currentLanguageCode;
    final dbTranslations = _vehicleSizeTranslations[vehicleId];
    if (dbTranslations != null) {
      final dbLabel = dbTranslations[lang] ?? dbTranslations['en'];
      if (dbLabel != null && dbLabel.isNotEmpty) return dbLabel;
    }

    // 2. Check language file keys
    final key = vehicleSizeLabelKeys[vehicleId];
    if (key != null) {
      final translated = LocalizationService.instance.t(key);
      if (translated != key) return translated;
    }

    // 3. Fallback to hardcoded label
    final option = vehicleSizeOptions.firstWhere(
      (v) => v['id'] == vehicleId,
      orElse: () => {'label': vehicleId},
    );
    return option['label'] as String;
  }

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
