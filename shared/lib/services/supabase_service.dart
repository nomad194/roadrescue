import 'dart:io';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../config/app_env.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await AppEnv.load();

      if (AppEnv.hasSupabaseCredentials) {
        await Supabase.initialize(
          url: AppEnv.supabaseUrl,
          anonKey: AppEnv.supabaseAnonKey,
        );
        _initialized = true;
        debugPrint('Supabase initialized successfully');
      } else {
        debugPrint('Supabase credentials missing');
      }
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ─── AUTH ────────────────────────────────────────────────────────────────

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': role},
    );
    return response;
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ─── JOBS ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProviderJobRequests({List<String>? categoryIds}) async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      // Get provider's geo settings
      final profile = await getUserProfile(userId);
      final providerStateId = profile?['selected_state_id'] as String?;
      final providerCityId = profile?['selected_city_id'] as String?;
      final providerLat = (profile?['address_lat'] as num?)?.toDouble();
      final providerLng = (profile?['address_lng'] as num?)?.toDouble();
      final serviceRange = (profile?['service_range_miles'] as num?)?.toDouble() ?? AppConstants.defaultServiceRangeMiles;

      debugPrint('=== Provider Job Requests Debug ===');
      debugPrint('Provider ID: $userId');
      debugPrint('Provider state_id: $providerStateId, city_id: $providerCityId');
      debugPrint('Provider coords: ($providerLat, $providerLng)');
      debugPrint('Service range: $serviceRange miles');
      debugPrint('Filtering by categoryIds: $categoryIds');

      // First, fetch jobs already assigned to this provider (always show these)
      final assignedJobsQuery = client
          .from('job_requests')
          .select('*, customer:customer_id(full_name, phone, avatar_url, address_lat, address_lng, selected_city_id, selected_state_id)')
          .eq('provider_id', userId)
          .neq('job_status', 'cancelled');
      
      // Then fetch pending jobs that might be in range
      // Exclude stale requests older than 24 hours to prevent ghost jobs
      final staleThreshold = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      var pendingQuery = client
          .from('job_requests')
          .select('*, customer:customer_id(full_name, phone, avatar_url, address_lat, address_lng, selected_city_id, selected_state_id)')
          .eq('job_status', 'pending')
          .isFilter('provider_id', null)
          .gte('created_at', staleThreshold);
      
      // No DB-level category or geo filtering — both done post-fetch
      // to avoid locale mismatch on service_type names

      // Execute both queries
      final assignedResponse = await assignedJobsQuery.order('created_at', ascending: false);
      final pendingResponse = await pendingQuery.order('created_at', ascending: false);

      final assignedJobs = List<Map<String, dynamic>>.from(assignedResponse);
      var pendingJobs = List<Map<String, dynamic>>.from(pendingResponse);

      // Post-fetch category filter using all name translations to avoid locale mismatch
      if (categoryIds != null && categoryIds.isNotEmpty) {
        final allCats = await getServiceCategories();
        final enabledCats = allCats.where((c) => categoryIds.contains(c['id']?.toString())).toList();
        final Set<String> allowedNames = {};
        for (final cat in enabledCats) {
          final baseName = cat['name'] as String?;
          if (baseName != null) allowedNames.add(baseName.toLowerCase());
          final translationsRaw = cat['name_translations'];
          Map<String, dynamic> translations = {};
          if (translationsRaw is Map) {
            translations = Map<String, dynamic>.from(translationsRaw);
          }
          for (final val in translations.values) {
            if (val is String) allowedNames.add(val.toLowerCase());
          }
        }
        debugPrint('Allowed service_type names for matching: $allowedNames');
        pendingJobs = pendingJobs.where((job) {
          final st = (job['service_type'] as String? ?? '').toLowerCase();
          final matches = allowedNames.contains(st);
          if (!matches) debugPrint('Job ${job["id"]}: service_type "$st" not in enabled categories, excluding');
          return matches;
        }).toList();
      }

      // Post-process pending jobs: filter by distance if provider has coordinates
      if (providerLat != null && providerLng != null) {
        pendingJobs = pendingJobs.where((job) {
          final jobLat = (job['customer_lat'] as num?)?.toDouble();
          final jobLng = (job['customer_lng'] as num?)?.toDouble();

          // Only include if job has coordinates within range
          if (jobLat != null && jobLng != null) {
            final distance = _calculateDistance(providerLat, providerLng, jobLat, jobLng);
            debugPrint('Job ${job['id']}: distance=${distance.toStringAsFixed(2)} miles, range=$serviceRange miles');
            return distance <= serviceRange;
          }

          // No coordinates on job — can't match, exclude it
          debugPrint('Job ${job['id']}: no GPS coordinates, excluding');
          return false;
        }).toList();
      } else {
        // Provider has no coordinates — can't do distance-based matching
        // Provider must set their address in profile to receive job requests
        debugPrint('Provider has no coordinates set in profile — cannot match jobs by distance');
        pendingJobs = []; // Clear pending jobs since we can't match them
      }

      // Combine: assigned jobs first, then pending jobs in range
      final combinedJobs = [...assignedJobs, ...pendingJobs];
      debugPrint('Final job count: ${combinedJobs.length} (assigned: ${assignedJobs.length}, pending: ${pendingJobs.length})');
      debugPrint('=== End Provider Job Requests Debug ===');
      return combinedJobs;
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      return [];
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 3959; // miles
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  Future<Map<String, dynamic>?> getActiveJobRequest() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      // Use limit(1) instead of maybeSingle() to handle edge cases where multiple active rows might exist (common in dev/testing)
      final response = await client
          .from('job_requests')
          .select(
            '*, provider:provider_id(id, full_name, phone, business_name, avatar_url)',
          )
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .inFilter('job_status', [
            'pending',
            'quoted',
            'accepted',
            'confirmed',
            'en_route',
            'in_progress',
            'awaiting_confirmation',
            'awaiting_reconfirmation',
            'disputed',
          ])
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return response.first;
    } catch (e) {
      debugPrint('Error fetching active job: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getJobHistory() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      // First get completed job requests
      final jobsResponse = await client
          .from('job_requests')
          .select(
            '*, customer:customer_id(full_name, avatar_url), provider:provider_id(full_name, business_name, avatar_url)',
          )
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .eq('job_status', 'completed')
          .order('created_at', ascending: false);

      final jobs = List<Map<String, dynamic>>.from(jobsResponse);
      
      // Get reviews for these jobs
      if (jobs.isNotEmpty) {
        final jobIds = jobs.map((j) => j['id'] as String).toList();
        final reviewsResponse = await client
            .from('reviews')
            .select('*')
            .inFilter('job_request_id', jobIds);
        
        final reviews = List<Map<String, dynamic>>.from(reviewsResponse);
        
        // Merge reviews into job data
        for (final job in jobs) {
          final jobReviews = reviews.where((r) => r['job_request_id'] == job['id']).toList();
          job['reviews'] = jobReviews;
          // Add customer_rating field for compatibility with UI
          final customerReview = jobReviews.firstWhere(
            (r) => r['reviewer_id'] == job['customer_id'],
            orElse: () => {},
          );
          if (customerReview.isNotEmpty) {
            job['customer_rating'] = customerReview['rating'];
            job['customer_review'] = customerReview['comment'];
          }
        }
      }
      
      return jobs;
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createJobRequest({
    required String serviceType,
    required String serviceIcon,
    String? serviceIconImageUrl,
    required String vehicleSize,
    required String address,
    required String description,
    required String urgency,
    double? customerLat,
    double? customerLng,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Pull customer geo data from their profile so providers can filter by location
    final profile = await getUserProfile(userId);
    final customerStateId = profile?['selected_state_id'] as String?;
    final customerCityId = profile?['selected_city_id'] as String?;
    final profileLat = (profile?['address_lat'] as num?)?.toDouble();
    final profileLng = (profile?['address_lng'] as num?)?.toDouble();
    final profileAddress = profile?['address'] as String?;

    // Prefer live GPS coords; fall back to profile coords
    final resolvedLat = customerLat ?? profileLat;
    final resolvedLng = customerLng ?? profileLng;
    // Prefer live GPS address; fall back to profile address
    final resolvedAddress = address.isNotEmpty
        ? address
        : (profileAddress?.isNotEmpty == true ? profileAddress! : '');

    final response = await client
        .from('job_requests')
        .insert({
          'customer_id': userId,
          'service_type': serviceType,
          'service_icon': serviceIcon,
          if (serviceIconImageUrl != null) 'service_icon_image_url': serviceIconImageUrl,
          'vehicle_size': vehicleSize,
          'address': resolvedAddress,
          'description': description,
          'urgency': urgency,
          'job_status': 'pending',
          if (customerStateId != null) 'customer_state_id': customerStateId,
          if (customerCityId != null) 'customer_city_id': customerCityId,
          if (resolvedLat != null) 'customer_lat': resolvedLat,
          if (resolvedLng != null) 'customer_lng': resolvedLng,
        })
        .select()
        .single();
    return response;
  }

  Future<void> sendQuote({
    required String requestId,
    required double price,
    required int etaMinutes,
    required String paymentMethods,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await client
        .from('job_requests')
        .update({
          'provider_id': userId,
          'quoted_price': price,
          'eta_minutes': etaMinutes,
          'accepted_payment_methods': paymentMethods,
          'job_status': 'quoted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  Future<void> cancelJobRequest(String requestId) async {
    await client
        .from('job_requests')
        .update({
          'job_status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  Future<void> markEnRoute(String requestId) async {
    await client
        .from('job_requests')
        .update({
          'job_status': 'en_route',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  /// Handles the complex completion confirmation logic
  Future<void> submitCompletionResponse({
    required String requestId,
    required String role, // 'customer' or 'provider'
    required bool confirmed,
  }) async {
    // 1. Fetch current state (bypass cache to get fresh data)
    final job = await client
        .from('job_requests')
        .select('job_status, customer_confirmation, provider_confirmation, confirmation_round')
        .eq('id', requestId)
        .single();

    final String currentStatus = job['job_status'] as String;
    final int currentRound = (job['confirmation_round'] as num?)?.toInt() ?? 0;
    
    // Get existing values from DB
    bool? customerConf = job['customer_confirmation'] as bool?;
    bool? providerConf = job['provider_confirmation'] as bool?;

    // 2. Update the specific role's flag
    if (role == 'customer') {
      customerConf = confirmed;
    } else {
      providerConf = confirmed;
    }

    String nextStatus = currentStatus;
    int nextRound = currentRound;

    // ─── LOGIC ENGINE ───

    if (currentStatus == 'accepted' || currentStatus == 'confirmed' || currentStatus == 'en_route' || currentStatus == 'in_progress') {
      // First person to tap "Completed"
      nextStatus = 'awaiting_confirmation';
      nextRound = 1;
    } 
    else if (currentStatus == 'awaiting_confirmation') {
      // Check if we now have agreement
      if (customerConf == true && providerConf == true) {
        nextStatus = 'completed';
        nextRound = 0;
        customerConf = null;
        providerConf = null;
      } else if (customerConf != null && providerConf != null) {
        // Mismatch occurred (one said Yes, other said No)
        nextStatus = 'awaiting_reconfirmation';
        nextRound = 2;
        customerConf = null;
        providerConf = null;
      }
    } 
    else if (currentStatus == 'awaiting_reconfirmation') {
      if (customerConf == true && providerConf == true) {
        nextStatus = 'completed';
        nextRound = 0;
        customerConf = null;
        providerConf = null;
      } else if (customerConf == false && providerConf == false) {
        nextStatus = 'in_progress';
        nextRound = 0;
        customerConf = null;
        providerConf = null;
      } else if (customerConf != null && providerConf != null) {
        nextStatus = 'disputed';
      }
    }

    // 3. Persist changes
    await client.from('job_requests').update({
      'job_status': nextStatus,
      'customer_confirmation': customerConf,
      'provider_confirmation': providerConf,
      'confirmation_round': nextRound,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String review,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // Ensure profile exists before submitting review
    final profileCreated = await ensureUserProfile(userId);
    if (!profileCreated) {
      throw Exception('Failed to create user profile - cannot submit review');
    }

    await client.from('reviews').insert({
      'job_request_id': bookingId,
      'reviewer_id': userId,
      'rating': rating,
      'comment': review,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all reviews for a provider
  Future<List<Map<String, dynamic>>> getProviderReviews(String providerId) async {
    try {
      final response = await client
          .from('reviews')
          .select('*, job:job_request_id(service_type, completed_at), reviewer:reviewer_id(full_name, avatar_url)')
          .eq('job.provider_id', providerId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching provider reviews: $e');
      return [];
    }
  }

  /// Get average rating for a provider using database function
  Future<Map<String, dynamic>> getProviderRating(String providerId) async {
    try {
      final response = await client
          .rpc('get_provider_rating', params: {'p_provider_id': providerId});
      
      if (response != null && response is List && response.isNotEmpty) {
        return {
          'average_rating': (response[0]['average_rating'] as num?)?.toDouble() ?? 0.0,
          'total_reviews': (response[0]['total_reviews'] as num?)?.toInt() ?? 0,
        };
      }
      return {'average_rating': 0.0, 'total_reviews': 0};
    } catch (e) {
      debugPrint('Error getting provider rating: $e');
      return {'average_rating': 0.0, 'total_reviews': 0};
    }
  }

  /// Add provider response to a review
  Future<void> addProviderResponse({
    required String reviewId,
    required String response,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await client.rpc('add_provider_response', params: {
      'p_review_id': reviewId,
      'p_response': response,
    });
  }

  /// Toggle review visibility (customer can make review public/private)
  Future<void> toggleReviewVisibility({
    required String reviewId,
    required bool isPublic,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await client
        .from('reviews')
        .update({'is_public': isPublic})
        .eq('id', reviewId)
        .eq('reviewer_id', userId);
  }

  RealtimeChannel subscribeToJobRequestUpdates(
    Function(Map<String, dynamic> record) onUpdate,
  ) {
    final channel = client.channel('public:job_requests');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_requests',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdate(payload.newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToJobRequest(
    String requestId,
    Function(Map<String, dynamic> record) onUpdate,
  ) {
    final channel = client.channel('job_request:$requestId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: requestId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  // ─── SUBSCRIPTIONS ───────────────────────────────────────────────────────

  /// Fetch the current active subscription for a provider
  Future<Map<String, dynamic>?> getActiveSubscription(String providerId) async {
    try {
      final response = await client
          .from('provider_subscriptions')
          .select('*, plan:plan_id(*)')
          .eq('provider_id', providerId)
          .eq('status', 'active')
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  // ─── CATEGORIES ──────────────────────────────────────────────────────────

  /// Fetch all active service categories
  Future<List<Map<String, dynamic>>> getServiceCategories() async {
    try {
      final response = await client
          .from('service_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ─── PROVIDER SETTINGS ───────────────────────────────────────────────────

  /// Fetch all configured services and pricing for a provider
  Future<List<Map<String, dynamic>>> getProviderServices(
    String providerId,
  ) async {
    try {
      debugPrint('Fetching provider services for: $providerId');
      final response = await client
          .from('provider_services')
          .select()
          .eq('provider_id', providerId);
      debugPrint('Raw response from DB: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching provider services: $e');
      return [];
    }
  }

  /// Ensure user profile exists (creates minimal profile if missing)
  /// This fixes the foreign key constraint error when saving services
  Future<bool> ensureUserProfile(String userId) async {
    try {
      // Check if profile exists
      final existing = await client
          .from('user_profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      if (existing == null) {
        debugPrint('Profile not found for $userId, creating minimal profile...');
        
        // Get current user info from session
        final currentUser = client.auth.currentUser;
        final email = currentUser?.email ?? '';
        final metadata = currentUser?.userMetadata ?? {};
        final fullName = metadata['full_name'] as String? ?? 'Provider';
        final phone = metadata['phone'] as String? ?? '';
        final role = metadata['role'] as String? ?? 'provider';
        
        debugPrint('Creating profile with: id=$userId, email=$email, role=$role');
        
        // Create minimal profile
        final result = await client.from('user_profiles').upsert({
          'id': userId,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Profile upsert result: $result');
        
        // Verify profile was created
        final verify = await client
            .from('user_profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
        if (verify != null) {
          debugPrint('Profile verified created successfully');
          return true;
        } else {
          debugPrint('ERROR: Profile creation failed - not found after upsert');
          return false;
        }
      } else {
        debugPrint('Profile already exists for $userId');
        return true;
      }
    } catch (e) {
      debugPrint('ERROR ensuring profile: $e');
      return false;
    }
  }

  /// Batch save all enabled services and their pricing
  Future<void> saveProviderServices(
    String providerId,
    List<Map<String, dynamic>> services,
  ) async {
    try {
      debugPrint('Saving ${services.length} services for provider: $providerId');
      
      // Ensure profile exists first (fixes foreign key constraint)
      final profileCreated = await ensureUserProfile(providerId);
      if (!profileCreated) {
        throw Exception('Failed to create user profile - cannot save services');
      }
      
      // 1. Delete existing for this provider
      debugPrint('Deleting existing services...');
      await client
          .from('provider_services')
          .delete()
          .eq('provider_id', providerId);
      debugPrint('Existing services deleted');

      // 2. Insert new ones
      if (services.isNotEmpty) {
        debugPrint('Inserting new services...');
        await client
            .from('provider_services')
            .insert(
              services
                  .map(
                    (s) => {
                      ...s,
                      'provider_id': providerId,
                      'updated_at': DateTime.now().toIso8601String(),
                    },
                  )
                  .toList(),
            );
        debugPrint('New services inserted successfully');
      } else {
        debugPrint('No services to insert');
      }
    } catch (e) {
      debugPrint('Error saving provider services: $e');
      rethrow;
    }
  }

  // ─── SETTINGS ────────────────────────────────────────────────────────────

  Future<Map<String, String>> getAppSettings(List<String> keys) async {
    try {
      final response = await client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', keys);

      final Map<String, String> settings = {
        for (final row in response as List)
          row['setting_key'] as String: row['setting_value'] as String,
      };
      return settings;
    } catch (_) {
      return {};
    }
  }

  Future<void> updateAppSetting(String key, String value) async {
    await client.from('app_settings').upsert({
      'setting_key': key,
      'setting_value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'setting_key');
  }

  // ─── PAYMENT METHODS ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await client
          .from('payment_methods')
          .select()
          .order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<void> updatePaymentMethod(
    String id,
    Map<String, dynamic> data,
  ) async {
    await client.from('payment_methods').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> createPaymentMethod(Map<String, dynamic> data) async {
    await client.from('payment_methods').insert({
      ...data,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── GEO ZONES ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStates() async {
    try {
      final response = await client
          .from('states')
          .select()
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching states: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCitiesByState(String stateId) async {
    try {
      final response = await client
          .from('cities')
          .select()
          .eq('state_id', stateId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching cities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllCities() async {
    try {
      final response = await client
          .from('cities')
          .select('*, states:state_id(code, name)')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all cities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGeoZones() async {
    try {
      final response = await client
          .from('geo_zones')
          .select('*, states:state_id(*), cities:city_id(*)')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching geo zones: $e');
      return [];
    }
  }

  Future<void> createGeoZone(Map<String, dynamic> data) async {
    await client.from('geo_zones').insert({
      ...data,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateGeoZone(String id, Map<String, dynamic> data) async {
    await client.from('geo_zones').update({
      ...data,
      'created_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteGeoZone(String id) async {
    await client.from('geo_zones').delete().eq('id', id);
  }

  Future<void> updateProviderGeoZone({
    required String providerId,
    String? stateId,
    String? cityId,
    String? geoZoneId,
    int? serviceRangeMiles,
    String? address,
    String? zipCode,
    double? addressLat,
    double? addressLng,
  }) async {
    final Map<String, dynamic> data = {
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (stateId != null) data['selected_state_id'] = stateId;
    if (cityId != null) data['selected_city_id'] = cityId;
    if (geoZoneId != null) data['selected_geo_zone_id'] = geoZoneId;
    if (serviceRangeMiles != null) data['service_range_miles'] = serviceRangeMiles;
    if (address != null) data['address'] = address;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (addressLat != null) data['address_lat'] = addressLat;
    if (addressLng != null) data['address_lng'] = addressLng;
    
    debugPrint('Updating user_profiles for $providerId with data: $data');
    
    try {
      final result = await client.from('user_profiles').update(data).eq('id', providerId);
      debugPrint('Update result: $result');
    } catch (e) {
      debugPrint('Update error: $e');
      rethrow;
    }
  }

  // ─── USER PROFILES ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await client.from('user_profiles').update(data).eq('id', userId);
  }

  Future<String?> getAppSetting(String key) async {
    try {
      final res = await client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', key)
          .maybeSingle();
      return res?['setting_value'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Upload avatar image to Supabase Storage and return the public URL
  Future<String> uploadAvatar(String userId, String filePath) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();
    final storagePath = 'avatars/$userId.$ext';

    await client.storage
        .from('avatars')
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
        );

    final publicUrl = client.storage
        .from('avatars')
        .getPublicUrl(storagePath);

    // Bust cache by appending timestamp
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Upload app asset (logo, background, etc.) to Supabase Storage and return the public URL
  Future<String?> uploadAppAsset(String bucket, String path, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last.toLowerCase();
      final storagePath = '$path.$ext';

      await client.storage
          .from(bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final publicUrl = client.storage
          .from(bucket)
          .getPublicUrl(storagePath);

      // Bust cache by appending timestamp
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Error uploading app asset: $e');
      return null;
    }
  }

  // ─── PROVIDER PAYMENT METHODS ──────────────────────────────────────────

  /// Get all enabled provider payment methods
  Future<List<Map<String, dynamic>>> getProviderPaymentMethods() async {
    try {
      final response = await client
          .from('provider_payment_methods')
          .select()
          .eq('is_enabled', true)
          .order('method_type');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching provider payment methods: $e');
      return [];
    }
  }

  /// Get all provider payment methods (for admin)
  Future<List<Map<String, dynamic>>> getAllProviderPaymentMethods() async {
    try {
      final response = await client
          .from('provider_payment_methods')
          .select()
          .order('method_type');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all provider payment methods: $e');
      return [];
    }
  }

  /// Update payment method settings (admin only)
  Future<void> updateProviderPaymentMethod(String id, {
    required bool isEnabled,
    required String instructions,
  }) async {
    await client.from('provider_payment_methods').update({
      'is_enabled': isEnabled,
      'instructions': instructions,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ─── PROVIDER SUBSCRIPTIONS ────────────────────────────────────────────────

  /// Get active subscription for a provider
  Future<Map<String, dynamic>?> getProviderActiveSubscription(String providerId) async {
    try {
      final response = await client
          .from('provider_subscriptions')
          .select('*, plan:plan_id(*)')
          .eq('provider_id', providerId)
          .eq('payment_status', 'completed')
          .gte('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching provider subscription: $e');
      return null;
    }
  }

  /// Create a new provider subscription (with trial support)
  Future<Map<String, dynamic>?> createProviderSubscription({
    required String providerId,
    required String planId,
    required String paymentMethod,
    required double amount,
    String billingCycle = 'monthly',
  }) async {
    try {
      // Get plan details to check for trial
      final planResponse = await client
          .from('subscription_plans')
          .select('trial_days')
          .eq('id', planId)
          .maybeSingle();

      final trialDays = (planResponse?['trial_days'] as num?)?.toInt() ?? 0;
      final hasTrial = trialDays > 0;

      // Calculate expiration based on billing cycle + trial
      final now = DateTime.now();
      final baseDuration = billingCycle == 'yearly'
          ? const Duration(days: 365)
          : const Duration(days: 30);
      final trialDuration = Duration(days: trialDays);
      final expiresAt = now.add(baseDuration).add(trialDuration);

      // If trial exists, mark as completed immediately so provider can use service
      final response = await client.from('provider_subscriptions').insert({
        'provider_id': providerId,
        'plan_id': planId,
        'payment_method': paymentMethod,
        'payment_status': hasTrial ? 'completed' : 'pending',
        'amount_paid': hasTrial ? 0.0 : amount, // No charge during trial
        'starts_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'admin_notes': hasTrial ? 'Trial period - $trialDays days' : null,
      }).select().single();

      return response;
    } catch (e) {
      debugPrint('Error creating provider subscription: $e');
      return null;
    }
  }

  /// Upload payment receipt for manual payments
  Future<String?> uploadPaymentReceipt(String subscriptionId, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last.toLowerCase();
      final storagePath = 'payment_receipts/$subscriptionId.$ext';

      await client.storage
          .from('app-assets')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final publicUrl = client.storage
          .from('app-assets')
          .getPublicUrl(storagePath);

      // Update subscription with receipt URL
      await client.from('provider_subscriptions').update({
        'payment_proof_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading payment receipt: $e');
      return null;
    }
  }

  /// Get pending subscriptions (for admin review)
  Future<List<Map<String, dynamic>>> getPendingProviderSubscriptions() async {
    try {
      final response = await client
          .from('provider_subscriptions')
          .select('*, plan:plan_id(*), provider:provider_id(full_name, email, phone)')
          .eq('payment_status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending subscriptions: $e');
      return [];
    }
  }

  /// Update payment status (admin only)
  Future<void> updateSubscriptionPaymentStatus(
    String subscriptionId, {
    required String status,
    String? adminNotes,
  }) async {
    await client.from('provider_subscriptions').update({
      'payment_status': status,
      'admin_notes': adminNotes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', subscriptionId);
  }

  // ─── PROVIDER SUBSCRIPTION STATE ────────────────────────────────────────

  /// Get the provider's subscription state (trial_used, paid_months, status, etc.)
  Future<Map<String, dynamic>> getProviderSubscriptionState(String providerId) async {
    try {
      final response = await client.rpc(
        'get_provider_subscription_state',
        params: {'p_provider_id': providerId},
      );
      if (response is Map<String, dynamic>) return response;
      // Default state for providers with no record
      return {
        'subscription_status': 'inactive',
        'trial_used': false,
        'paid_months': 0,
        'trial_reset_allowed': false,
        'plan_id': null,
        'trial_plan_id': null,
      };
    } catch (e) {
      debugPrint('Error fetching subscription state: $e');
      return {
        'subscription_status': 'inactive',
        'trial_used': false,
        'paid_months': 0,
        'trial_reset_allowed': false,
        'plan_id': null,
        'trial_plan_id': null,
      };
    }
  }

  /// Call the manage-subscription Edge Function
  Future<Map<String, dynamic>> manageSubscription({
    required String action,
    String? providerId,
    String? planId,
    String? billingCycle,
    double? amount,
    String? paymentMethod,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': action,
        if (providerId != null) 'provider_id': providerId,
        if (planId != null) 'plan_id': planId,
        if (billingCycle != null) 'billing_cycle': billingCycle,
        if (amount != null) 'amount': amount,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      };

      final response = await client.functions.invoke(
        'manage-subscription',
        body: body,
      );

      if (response.status != 200) {
        final errorData = response.data;
        final errorMsg = errorData is Map ? errorData['error']?.toString() ?? 'Unknown error' : 'Request failed';
        debugPrint('manage-subscription error ($action): $errorMsg');
        return {'ok': false, 'error': errorMsg};
      }

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'ok': false, 'error': 'Invalid response format'};
    } catch (e) {
      debugPrint('manage-subscription exception ($action): $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Start a free trial for a provider via Edge Function
  Future<Map<String, dynamic>> startProviderTrial({
    required String providerId,
    required String planId,
  }) async {
    return manageSubscription(
      action: 'start_trial',
      providerId: providerId,
      planId: planId,
    );
  }

  /// Activate a paid subscription via Edge Function
  Future<Map<String, dynamic>> activateProviderSubscription({
    required String providerId,
    required String planId,
    String billingCycle = 'monthly',
    double amount = 0,
    String paymentMethod = 'online',
  }) async {
    return manageSubscription(
      action: 'activate',
      providerId: providerId,
      planId: planId,
      billingCycle: billingCycle,
      amount: amount,
      paymentMethod: paymentMethod,
    );
  }

  /// Expire / pause a provider's subscription
  Future<Map<String, dynamic>> expireProviderSubscription(String providerId) async {
    return manageSubscription(
      action: 'expire',
      providerId: providerId,
    );
  }

  /// Record a completed paid month (unlocks trial reset)
  Future<Map<String, dynamic>> completePaidMonth(String providerId) async {
    return manageSubscription(
      action: 'complete_month',
      providerId: providerId,
    );
  }

  /// Check current subscription status via Edge Function
  Future<Map<String, dynamic>> checkSubscriptionStatus(String providerId) async {
    return manageSubscription(
      action: 'check_status',
      providerId: providerId,
    );
  }

  // ─── PROVIDER DOCUMENTS ─────────────────────────────────────────────────

  /// Get all active required document types
  Future<List<Map<String, dynamic>>> getRequiredDocumentTypes() async {
    try {
      final response = await client
          .from('required_document_types')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching required doc types: $e');
      return [];
    }
  }

  /// Get all required document types (including inactive) for admin
  Future<List<Map<String, dynamic>>> getAllDocumentTypes() async {
    try {
      final response = await client
          .from('required_document_types')
          .select()
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all doc types: $e');
      return [];
    }
  }

  /// Create a new required document type
  Future<Map<String, dynamic>?> createDocumentType(Map<String, dynamic> data) async {
    try {
      final response = await client
          .from('required_document_types')
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error creating doc type: $e');
      return null;
    }
  }

  /// Update a required document type
  Future<bool> updateDocumentType(int id, Map<String, dynamic> data) async {
    try {
      await client
          .from('required_document_types')
          .update(data)
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating doc type: $e');
      return false;
    }
  }

  /// Soft-delete a document type (set is_active = false)
  Future<bool> deactivateDocumentType(int id) async {
    return updateDocumentType(id, {'is_active': false});
  }

  /// Get provider's uploaded documents
  Future<List<Map<String, dynamic>>> getProviderDocuments(String providerId) async {
    try {
      final response = await client
          .from('provider_documents')
          .select('*, required_document_types(*)')
          .eq('provider_id', providerId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching provider documents: $e');
      return [];
    }
  }

  /// Get all provider documents for admin review (with provider info)
  Future<List<Map<String, dynamic>>> getAllProviderDocuments({String? statusFilter}) async {
    try {
      var query = client
          .from('provider_documents')
          .select('*, required_document_types(*), user_profiles!provider_documents_provider_id_fkey(id, full_name, email, avatar_url)');
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }
      final response = await query.order('uploaded_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all provider documents: $e');
      return [];
    }
  }

  /// Upload a document file to storage and upsert the provider_documents row
  Future<Map<String, dynamic>?> uploadProviderDocument({
    required String providerId,
    required int documentTypeId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last.toLowerCase();
      final storagePath = '$providerId/${documentTypeId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await client.storage
          .from('provider-documents')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final fileUrl = client.storage
          .from('provider-documents')
          .getPublicUrl(storagePath);

      // Upsert the document record (re-upload resets status to pending)
      final response = await client
          .from('provider_documents')
          .upsert({
            'provider_id': providerId,
            'document_type_id': documentTypeId,
            'file_url': '$fileUrl?t=${DateTime.now().millisecondsSinceEpoch}',
            'status': 'pending',
            'rejection_reason': null,
            'uploaded_at': DateTime.now().toIso8601String(),
            'reviewed_at': null,
            'reviewed_by': null,
          }, onConflict: 'provider_id,document_type_id')
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error uploading provider document: $e');
      return null;
    }
  }

  /// Admin: approve a document
  Future<bool> approveProviderDocument(String documentId, String reviewerId) async {
    try {
      await client
          .from('provider_documents')
          .update({
            'status': 'approved',
            'rejection_reason': null,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': reviewerId,
          })
          .eq('id', documentId);
      return true;
    } catch (e) {
      debugPrint('Error approving document: $e');
      return false;
    }
  }

  /// Admin: reject a document with reason
  Future<bool> rejectProviderDocument(String documentId, String reviewerId, String reason) async {
    try {
      await client
          .from('provider_documents')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': reviewerId,
          })
          .eq('id', documentId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      return false;
    }
  }

  /// Get audit trail for a document
  Future<List<Map<String, dynamic>>> getDocumentAuditTrail(String documentId) async {
    try {
      final response = await client
          .from('provider_document_audit')
          .select('*, user_profiles!provider_document_audit_changed_by_fkey(full_name)')
          .eq('document_id', documentId)
          .order('changed_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching document audit: $e');
      return [];
    }
  }

  /// Check if a provider has all required documents verified
  Future<bool> isProviderDocumentsVerified(String providerId) async {
    try {
      final requiredTypes = await getRequiredDocumentTypes();
      if (requiredTypes.isEmpty) return true; // No docs required

      final providerDocs = await getProviderDocuments(providerId);
      final approvedTypeIds = providerDocs
          .where((d) => d['status'] == 'approved')
          .map((d) => d['document_type_id'] as int)
          .toSet();

      final requiredTypeIds = requiredTypes.map((t) => t['id'] as int).toSet();
      return requiredTypeIds.every((id) => approvedTypeIds.contains(id));
    } catch (e) {
      debugPrint('Error checking provider docs verified: $e');
      return false;
    }
  }

  // ─── PASSWORD RESET ─────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  Future<bool> verifyPasswordResetOTP({required String email, String? otp, String? token}) async {
    final code = otp ?? token ?? '';
    try {
      final response = await client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      return response.session != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ─── ACCOUNT DELETION ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> deleteUserAccount([String? userId]) async {
    try {
      await client.functions.invoke('delete-account', body: {'user_id': userId ?? currentUser?.id});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
