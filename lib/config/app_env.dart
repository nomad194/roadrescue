import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads Supabase and Stripe keys from compile-time defines or bundled [env.json].
class AppEnv {
  static String supabaseUrl = '';
  static String supabaseAnonKey = '';
  static String stripePublishableKey = '';
  static String googleWebClientId = '';

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Call before [SupabaseService.initialize].
  static Future<void> load() async {
    const urlFromDefine = String.fromEnvironment('SUPABASE_URL');
    const anonFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    const stripeFromDefine = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    const googleWebClientIdFromDefine = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

    if (urlFromDefine.isNotEmpty && anonFromDefine.isNotEmpty) {
      supabaseUrl = urlFromDefine;
      supabaseAnonKey = anonFromDefine;
      stripePublishableKey = stripeFromDefine;
      googleWebClientId = googleWebClientIdFromDefine;
      debugPrint('AppEnv: loaded from dart-define');
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString('env.json');
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      supabaseUrl = map['SUPABASE_URL'] as String? ?? '';
      supabaseAnonKey = map['SUPABASE_ANON_KEY'] as String? ?? '';
      stripePublishableKey = map['STRIPE_PUBLISHABLE_KEY'] as String? ?? '';
      googleWebClientId = map['GOOGLE_WEB_CLIENT_ID'] as String? ?? '';
      if (hasSupabaseCredentials) {
        debugPrint('AppEnv: loaded from bundled env.json');
      }
    } catch (e) {
      debugPrint('AppEnv: could not load env.json asset: $e');
    }
  }
}
