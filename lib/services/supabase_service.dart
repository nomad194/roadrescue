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

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ─── JOBS ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProviderJobRequests() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await client
          .from('job_requests')
          .select('*, customer:customer_id(full_name, phone, avatar_url)')
          .order('created_at', ascending: false);
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
      final response = await client
          .from('job_requests')
          .select('*, provider:provider_id(id, full_name, phone, business_name, avatar_url)')
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .inFilter('job_status', ['pending', 'quoted', 'accepted', 'confirmed', 'en_route', 'in_progress'])
          .order('created_at', ascending: false)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
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

    await client.from('job_requests').update({
      'provider_id': userId,
      'quoted_price': price,
      'eta_minutes': etaMinutes,
      'accepted_payment_methods': paymentMethods,
      'job_status': 'quoted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> cancelJobRequest(String requestId) async {
    await client
        .from('job_requests')
        .update({'job_status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }

  Future<void> markEnRoute(String requestId) async {
    await client
        .from('job_requests')
        .update({'job_status': 'en_route', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }

  RealtimeChannel subscribeToJobRequestUpdates(Function(Map<String, dynamic> record) onUpdate) {
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

  RealtimeChannel subscribeToJobRequest(String requestId, Function(Map<String, dynamic> record) onUpdate) {
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
  Future<List<Map<String, dynamic>>> getProviderServices(String providerId) async {
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
  Future<void> saveProviderServices(String providerId, List<Map<String, dynamic>> services) async {
    // 1. Delete existing for this provider
    await client.from('provider_services').delete().eq('provider_id', providerId);
    
    // 2. Insert new ones
    if (services.isNotEmpty) {
      await client.from('provider_services').insert(
        services.map((s) => {
          ...s,
          'provider_id': providerId,
          'updated_at': DateTime.now().toIso8601String(),
        }).toList()
      );
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
    await client
        .from('user_profiles')
        .update(data)
        .eq('id', userId);
  }
}
