import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      const url = String.fromEnvironment('SUPABASE_URL');
      const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      if (url.isNotEmpty && anonKey.isNotEmpty) {
        await Supabase.initialize(url: url, anonKey: anonKey);
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

  Future<List<Map<String, dynamic>>> getProviderJobRequests({List<String>? categories}) async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      var query = client
          .from('job_requests')
          .select('*, customer:customer_id(full_name, phone, avatar_url)');

      if (categories != null && categories.isNotEmpty) {
        // filter for jobs matching my active categories OR jobs already assigned to me
        // We use double quotes for category names to handle spaces correctly in PostgREST .or()
        final catList = categories.map((c) => '"$c"').join(',');
        query = query.or('service_type.in.($catList),provider_id.eq.$userId');
      } else if (categories != null && categories.isEmpty) {
        // Only show jobs explicitly assigned to me if no categories are enabled
        query = query.eq('provider_id', userId);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      return [];
    }
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
      final response = await client
          .from('job_requests')
          .select(
            '*, customer:customer_id(full_name), provider:provider_id(full_name, business_name, avatar_url)',
          )
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .eq('job_status', 'completed')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createJobRequest({
    required String serviceType,
    required String serviceIcon,
    required String vehicleSize,
    required String address,
    required String description,
    required String urgency,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await client
        .from('job_requests')
        .insert({
          'customer_id': userId,
          'service_type': serviceType,
          'service_icon': serviceIcon,
          'vehicle_size': vehicleSize,
          'address': address,
          'description': description,
          'urgency': urgency,
          'job_status': 'pending',
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
    if (userId == null) return;

    await client.from('reviews').insert({
      'job_request_id': bookingId,
      'reviewer_id': userId,
      'rating': rating,
      'comment': review,
      'created_at': DateTime.now().toIso8601String(),
    });
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
      final response = await client
          .from('provider_services')
          .select()
          .eq('provider_id', providerId);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Batch save all enabled services and their pricing
  Future<void> saveProviderServices(
    String providerId,
    List<Map<String, dynamic>> services,
  ) async {
    // 1. Delete existing for this provider
    await client
        .from('provider_services')
        .delete()
        .eq('provider_id', providerId);

    // 2. Insert new ones
    if (services.isNotEmpty) {
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
}
