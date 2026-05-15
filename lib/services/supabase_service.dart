import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ SUPABASE CONFIGURATION MISSING');
      debugPrint('Please provide SUPABASE_URL and SUPABASE_ANON_KEY.');
      return;
    }
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully.');
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
    }
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        'Supabase is not initialized. Check your SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return Supabase.instance.client;
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────

  User? get currentUser => client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': role},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
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

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await client.from('user_profiles').update(data).eq('id', userId);
  }

  // ─── JOB REQUESTS ────────────────────────────────────────────────────────

  /// Customer: submit a new help request
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

  /// Customer: get their active (non-completed/cancelled) request
  Future<Map<String, dynamic>?> getActiveJobRequest() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await client
          .from('job_requests')
          .select(
            '*, provider:provider_id(id, full_name, phone, business_name, avatar_url)',
          )
          .eq('customer_id', userId)
          .inFilter('job_status', [
            'pending',
            'quoted',
            'accepted',
            'confirmed',
            'in_progress',
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Customer: cancel their job request
  Future<void> cancelJobRequest(String requestId) async {
    await client
        .from('job_requests')
        .update({'job_status': 'cancelled'})
        .eq('id', requestId);
  }

  /// Provider: get all open job requests (pending/quoted)
  Future<List<Map<String, dynamic>>> getProviderJobRequests() async {
    try {
      final response = await client
          .from('job_requests')
          .select('*, customer:customer_id(id, full_name, phone, avatar_url)')
          .inFilter('job_status', [
            'pending',
            'quoted',
            'accepted',
            'confirmed',
            'in_progress',
            'completed',
          ])
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Provider: send a quote for a job request
  Future<void> sendQuote({
    required String requestId,
    required double price,
    required int etaMinutes,
    String notes = '',
    String paymentMethods = 'cash,online',
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await client
        .from('job_requests')
        .update({
          'job_status': 'quoted',
          'provider_id': userId,
          'quoted_price': price,
          'eta_minutes': etaMinutes,
          'provider_notes': notes,
          'accepted_payment_methods': paymentMethods,
        })
        .eq('id', requestId);
  }

  /// Provider: mark job as en_route (On My Way)
  Future<void> markEnRoute(String requestId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await client
        .from('job_requests')
        .update({
          'job_status': 'en_route',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .or('provider_id.eq.$userId,provider_id.is.null');
  }

  /// Provider: accept/confirm a job (creates booking)
  Future<void> confirmJob(String requestId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Update job status
    final jobData = await client
        .from('job_requests')
        .update({'job_status': 'confirmed', 'provider_id': userId})
        .eq('id', requestId)
        .select()
        .single();

    // Create booking record
    await client.from('bookings').insert({
      'job_request_id': requestId,
      'customer_id': jobData['customer_id'],
      'provider_id': userId,
      'final_price': jobData['quoted_price'],
      'booking_status': 'confirmed',
    });
  }

  /// Provider: mark job as completed
  Future<void> completeJob(String requestId) async {
    await client
        .from('job_requests')
        .update({'job_status': 'completed'})
        .eq('id', requestId);

    await client
        .from('bookings')
        .update({
          'booking_status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('job_request_id', requestId);
  }

  // ─── HISTORY & REVIEWS ───────────────────────────────────────────────────

  /// Fetch history of bookings for current user (customer or provider)
  Future<List<Map<String, dynamic>>> getJobHistory() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('bookings')
          .select('*, job_request:job_request_id(*), provider:provider_id(full_name, business_name, avatar_url), customer:customer_id(full_name, avatar_url)')
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .order('completed_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Submit a review for a completed booking
  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String review,
  }) async {
    await client
        .from('bookings')
        .update({
          'customer_rating': rating,
          'customer_review': review,
        })
        .eq('id', bookingId);
  }

  /// Generic helper to fetch app settings
  Future<Map<String, dynamic>> getAppSettings(List<String> keys) async {
    try {
      final response = await client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', keys);
      
      final Map<String, dynamic> result = {};
      for (final row in response as List) {
        result[row['setting_key']] = row['setting_value'];
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  // ─── REAL-TIME SUBSCRIPTIONS ─────────────────────────────────────────────

  /// Customer: subscribe to updates on their active job request
  RealtimeChannel subscribeToJobRequest(
    String requestId,
    void Function(Map<String, dynamic> record) onUpdate,
  ) {
    return client
        .channel('job_request_$requestId')
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
            if (payload.newRecord.isNotEmpty) {
              onUpdate(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  /// Provider: subscribe to new job requests
  RealtimeChannel subscribeToNewJobRequests(
    void Function(Map<String, dynamic> record) onInsert,
  ) {
    return client
        .channel('new_job_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_requests',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onInsert(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  /// Provider: subscribe to updates on all job requests
  RealtimeChannel subscribeToJobRequestUpdates(
    void Function(Map<String, dynamic> record) onUpdate,
  ) {
    return client
        .channel('job_requests_updates')
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
  }
}
