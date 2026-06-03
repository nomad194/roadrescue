import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Service for handling social authentication (Google, Apple, Facebook)
class AuthSocialService {
  static final AuthSocialService instance = AuthSocialService._();
  AuthSocialService._();

  final SupabaseClient _client = SupabaseService.instance.client;

  /// Generate a cryptographically secure nonce for Apple Sign In
  String _generateNonce() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// Generate SHA256 hash of nonce for Apple Sign In
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Google using Supabase OAuth browser flow
  /// Returns true if the OAuth flow was launched successfully.
  /// Profile is created via auth state listener after redirect.
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Google sign in: launching OAuth browser flow');
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return success;
    } on AuthException catch (e) {
      debugPrint('Google sign in AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  /// Sign in with Apple using native SDK
  /// Returns AuthResponse on success, throws exception on failure
  Future<AuthResponse> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Get ID token
      final String? idToken = appleCredential.identityToken;

      if (idToken == null) {
        throw Exception('Failed to get Apple ID token');
      }

      // Sign in to Supabase with the ID token
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Build full name from Apple credential
      final givenName = appleCredential.givenName ?? '';
      final familyName = appleCredential.familyName ?? '';
      final fullName = '$givenName $familyName'.trim();

      // Ensure user profile exists after social login
      await _ensureUserProfileAfterSocialLogin(
        user: response.user,
        email: appleCredential.email ?? response.user?.email ?? '',
        fullName: fullName.isNotEmpty ? fullName : (response.user?.userMetadata?['full_name'] as String? ?? ''),
      );

      return response;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple sign in authorization exception: ${e.message}');
      rethrow;
    } on AuthException catch (e) {
      debugPrint('Apple sign in AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Apple sign in error: $e');
      rethrow;
    }
  }

  /// Sign in with Facebook using OAuth redirect
  /// This opens a browser for Facebook OAuth flow
  Future<bool> signInWithFacebook() async {
    try {
      // Use Supabase OAuth flow (opens browser)
      final bool success = await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _getRedirectUrl(),
      );

      return success;
    } on AuthException catch (e) {
      debugPrint('Facebook sign in AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Facebook sign in error: $e');
      rethrow;
    }
  }

  /// Get appropriate redirect URL based on platform
  String _getRedirectUrl() {
    if (kIsWeb) {
      return '${Uri.base.origin}/auth/callback';
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Deep link back to app after OAuth
      // Must match AndroidManifest.xml intent-filter and Supabase Redirect URLs
      return 'io.supabase.roadrescue://login-callback';
    }
    return '';
  }

  /// Ensure user profile exists after social login
  /// Creates or updates profile with info from social provider
  Future<void> _ensureUserProfileAfterSocialLogin({
    required User? user,
    required String email,
    required String fullName,
  }) async {
    if (user == null) return;

    try {
      // Check if profile exists
      final existingProfile = await SupabaseService.instance.getUserProfile(user.id);

      if (existingProfile == null) {
        // Create new profile for social login user
        final metadata = user.userMetadata;
        final role = metadata?['role'] as String? ?? 'customer';
        final phone = metadata?['phone'] as String? ?? '';

        await _client.from('user_profiles').upsert({
          'id': user.id,
          'email': email.isNotEmpty ? email : user.email,
          'full_name': fullName.isNotEmpty ? fullName : (metadata?['full_name'] as String? ?? 'User'),
          'phone': phone,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        debugPrint('Created user profile for social login user: ${user.id}');
      } else {
        // Update last login time
        await _client.from('user_profiles').update({
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error ensuring user profile after social login: $e');
      // Don't throw - allow login to proceed even if profile creation fails
      // It will be retried on next login
    }
  }

  /// Sign out from all social providers
  Future<void> signOut() async {
    try {
      // Sign out from Supabase (handles all providers)
      await SupabaseService.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out from social providers: $e');
      rethrow;
    }
  }

  /// Check if Google Sign-In is available on this platform
  bool get isGoogleSignInAvailable {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Check if Apple Sign-In is available on this platform
  bool get isAppleSignInAvailable {
    if (kIsWeb) return false; // Apple Sign-In works on web but requires special setup
    return Platform.isIOS || Platform.isMacOS || Platform.isAndroid;
  }

  /// Check if Facebook Sign-In is available on this platform
  bool get isFacebookSignInAvailable {
    return true; // Available on all platforms via OAuth redirect
  }

  /// Handle post-social-auth: ensure profile exists, return true if new user
  Future<bool> handlePostSocialAuth(User? user) async {
    if (user == null) return false;
    try {
      final profile = await SupabaseService.instance.getUserProfile(user.id);
      if (profile == null) {
        await _client.from('user_profiles').upsert({
          'id': user.id,
          'email': user.email ?? '',
          'role': 'customer',
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
