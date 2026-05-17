import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Conditional import for mobile notifications
import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_mobile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!kIsWeb) {
        await initializeMobileNotifications();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (kIsWeb) {
        // Web: use browser notification API via dart:html is not available here
        // We show a SnackBar-style in-app notification instead
        debugPrint('Web notification: $title - $body');
      } else {
        await showMobileNotification(
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  // ─── REAL-TIME NOTIFICATION LISTENERS ───────────────────────────────────

  RealtimeChannel? _userSubscription;
  RealtimeChannel? _providerSubscription;

  void startListening(String userId) async {
    _userSubscription?.unsubscribe();
    _providerSubscription?.unsubscribe();

    // Fetch profile to check role
    final profile = await Supabase.instance.client
        .from('user_profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = profile?['role'] ?? 'customer';

    if (role == 'customer') {
      // Listen for updates on job_requests where current user is customer
      _userSubscription = Supabase.instance.client
          .channel('user_notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'job_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: userId,
            ),
            callback: (payload) {
              final newStatus = payload.newRecord['job_status'];
              final oldStatus = payload.oldRecord['job_status'];
              if (newStatus != oldStatus) {
                _handleStatusChange(payload.newRecord);
              }
            },
          )
          .subscribe();
    } else if (role == 'provider') {
      // Listen for NEW job requests (providers want to know about new jobs)
      _providerSubscription = Supabase.instance.client
          .channel('provider_notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'job_requests',
            callback: (payload) {
              notifyNewJobRequest(
                payload.newRecord['service_type'] ?? 'Service',
                payload.newRecord['address'] ?? 'Nearby',
              );
            },
          )
          .subscribe();
    }
  }

  void stopListening() {
    _userSubscription?.unsubscribe();
    _userSubscription = null;
    _providerSubscription?.unsubscribe();
    _providerSubscription = null;
  }

  void _handleStatusChange(Map<String, dynamic> record) {
    final status = record['job_status'];

    switch (status) {
      case 'quoted':
        notifyQuoteReceived(
          'A provider',
          (record['quoted_price'] as num?)?.toDouble() ?? 0.0,
        );
        break;
      case 'confirmed':
        notifyBookingConfirmed('Your provider');
        break;
      case 'en_route':
        notifyCustomerEnRoute('Your provider');
        break;
      case 'completed':
        notifyJobCompleted((record['quoted_price'] as num?)?.toDouble() ?? 0.0);
        break;
    }
  }

  // Save push token to Supabase for server-side push
  Future<void> savePushToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, token');
    } catch (e) {
      debugPrint('Save push token error: $e');
    }
  }

  // Notification types for the app
  Future<void> notifyNewJobRequest(String serviceType, String address) async {
    await showLocalNotification(
      title: '🚨 New Job Request',
      body: '$serviceType at $address',
      payload: 'new_job',
    );
  }

  Future<void> notifyQuoteReceived(String providerName, double price) async {
    await showLocalNotification(
      title: '💰 Quote Received',
      body: '$providerName quoted \$${price.toStringAsFixed(2)}',
      payload: 'quote_received',
    );
  }

  Future<void> notifyBookingConfirmed(String providerName) async {
    await showLocalNotification(
      title: '✅ Booking Confirmed',
      body: '$providerName is on the way!',
      payload: 'booking_confirmed',
    );
  }

  Future<void> notifyJobCompleted(double amount) async {
    await showLocalNotification(
      title: '🎉 Job Completed',
      body: 'Service completed. Total: \$${amount.toStringAsFixed(2)}',
      payload: 'job_completed',
    );
  }

  Future<void> notifyPaymentReceived(double amount) async {
    await showLocalNotification(
      title: '💳 Payment Received',
      body: 'You received \$${amount.toStringAsFixed(2)}',
      payload: 'payment_received',
    );
  }

  Future<void> notifyProviderQuoteAcceptedOnline(String serviceType) async {
    await showLocalNotification(
      title: '✅ Quote Accepted & Paid',
      body:
          'Your quote for $serviceType has been accepted and paid. Order confirmed.',
      payload: 'booking_confirmed_online',
    );
  }

  Future<void> notifyProviderQuoteAcceptedCOD(String serviceType) async {
    await showLocalNotification(
      title: '✅ Quote Accepted (COD)',
      body:
          'Your quote for $serviceType has been accepted. Order confirmed (COD).',
      payload: 'booking_confirmed_cod',
    );
  }

  Future<void> notifyCustomerEnRoute(String providerName) async {
    await showLocalNotification(
      title: '🚗 Provider On The Way',
      body: '$providerName is on the way to your location.',
      payload: 'provider_en_route',
    );
  }
}
