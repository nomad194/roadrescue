import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling GPS location acquisition and caching
class LocationService {
  static const String _cacheKey = 'last_known_location';
  static const double _poorAccuracyThreshold = 50.0; // meters

  /// Request location permission from user
  static Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current GPS position with timeout
  /// Returns null if timeout or permission denied
  static Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Check permission
      final permission = await requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        return null;
      }

      // Check if location services are enabled
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        debugPrint('Location services disabled');
        return null;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(timeout, onTimeout: () {
        debugPrint('GPS acquisition timed out after ${timeout.inSeconds}s');
        throw TimeoutException('GPS timed out');
      });

      debugPrint('GPS acquired: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      return position;
    } on TimeoutException {
      debugPrint('GPS timeout');
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to address using Nominatim (OpenStreetMap)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RoadRescueApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'] as String;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Geocode address to coordinates using Nominatim
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      final query = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'RoadRescueApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lng': double.parse(data[0]['lon']),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }

  /// Check if GPS accuracy is poor (> 50m)
  static bool isAccuracyPoor(Position position) {
    return position.accuracy > _poorAccuracyThreshold;
  }

  /// Save last known location to SharedPreferences
  static Future<void> saveLastKnownLocation(
    double lat,
    double lng,
    String address,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'lat': lat,
        'lng': lng,
        'address': address,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(locationData));
      debugPrint('Location cached: $address');
    } catch (e) {
      debugPrint('Error caching location: $e');
    }
  }

  /// Retrieve cached location from SharedPreferences
  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        debugPrint('Retrieved cached location: ${data['address']}');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error retrieving cached location: $e');
      return null;
    }
  }

  /// Clear cached location
  static Future<void> clearCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      debugPrint('Error clearing cached location: $e');
    }
  }

  /// Get static OpenStreetMap tile URL for map preview
  static String getStaticMapUrl(double lat, double lng, {int zoom = 16}) {
    // Using OpenStreetMap static tiles via Mapbox or directly
    // For simplicity, using a static map service or generating tile URL
    // This generates a URL that can be used with Image.network
    return 'https://static-maps.openstreetmap.org/?center=$lat,$lng&zoom=$zoom&size=600x300&markers=$lat,$lng';
  }

  /// Alternative: Generate OSM tile URL for flutter_map
  static String getOsmTileUrl() {
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
