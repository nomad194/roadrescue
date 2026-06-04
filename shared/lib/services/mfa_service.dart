import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Service for handling MFA (Multi-Factor Authentication) phone verification
class MfaService {
  static final MfaService instance = MfaService._();
  MfaService._();

  final SupabaseClient _client = SupabaseService.instance.client;

  /// Enroll a phone number for SMS MFA
  /// Returns the factor ID on success
  Future<String> enrollPhone(String phoneNumber) async {
    try {
      final response = await _client.auth.mfa.enroll(
        factorType: FactorType.totp, // Note: Supabase uses totp for phone via SMS
        friendlyName: 'Phone: $phoneNumber',
      );

      debugPrint('Phone MFA enrollment initiated: ${response.id}');
      return response.id;
    } on AuthException catch (e) {
      debugPrint('Phone enrollment AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Phone enrollment error: $e');
      rethrow;
    }
  }

  /// Verify phone MFA with code
  /// Takes the factor ID and the OTP code from SMS
  Future<Map<String, dynamic>> verifyPhone({
    required String factorId,
    required String code,
  }) async {
    try {
      // First create a challenge
      final challenge = await _client.auth.mfa.challenge(
        factorId: factorId,
      );

      // Then verify the challenge with the code
      await _client.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );

      debugPrint('Phone MFA verified successfully');
      // Return simple success map - AuthMFAVerifyResponse doesn't expose id/type
      return {'success': true};
    } on AuthException catch (e) {
      debugPrint('Phone verify AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Phone verify error: $e');
      rethrow;
    }
  }

  /// Challenge and verify in one call (convenience method)
  Future<Map<String, dynamic>> challengeAndVerify({
    required String factorId,
    required String code,
  }) async {
    return await verifyPhone(factorId: factorId, code: code);
  }

  /// Get all enrolled MFA factors for current user
  Future<List<Map<String, dynamic>>> getEnrolledFactors() async {
    try {
      final response = await _client.auth.mfa.listFactors();
      // Convert factors to maps manually since toJson() may not be available
      return response.all.map((factor) => {
        'id': factor.id,
        'status': factor.status,
        'friendly_name': factor.friendlyName,
        'factor_type': factor.factorType,
        'created_at': factor.createdAt.toIso8601String(),
        'updated_at': factor.updatedAt.toIso8601String(),
      }).toList();
    } on AuthException catch (e) {
      debugPrint('List factors AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('List factors error: $e');
      rethrow;
    }
  }

  /// Unenroll a factor by ID
  /// Use this when user wants to change phone number
  Future<void> unenrollFactor(String factorId) async {
    try {
      await _client.auth.mfa.unenroll(factorId);
      debugPrint('Factor unenrolled: $factorId');
    } on AuthException catch (e) {
      debugPrint('Unenroll AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unenroll error: $e');
      rethrow;
    }
  }

  /// Update user's phone number in profile
  /// This updates the phone column in user_profiles
  Future<void> updateProfilePhone(String userId, String phoneNumber) async {
    try {
      await _client.from('user_profiles').update({
        'phone': phoneNumber,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('Profile phone updated: $phoneNumber');
    } catch (e) {
      debugPrint('Update profile phone error: $e');
      rethrow;
    }
  }

  /// Mark phone as verified in user profile
  /// Sets phone_verified_at to current timestamp
  Future<void> markPhoneVerified(String userId) async {
    try {
      await _client.from('user_profiles').update({
        'phone_verified_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('Phone marked as verified for user: $userId');
    } catch (e) {
      debugPrint('Mark phone verified error: $e');
      rethrow;
    }
  }

  /// Check if user's phone is verified
  /// Returns true if phone_verified_at is not null
  Future<bool> isPhoneVerified(String userId) async {
    try {
      final profile = await SupabaseService.instance.getUserProfile(userId);
      final verifiedAt = profile?['phone_verified_at'];
      return verifiedAt != null;
    } catch (e) {
      debugPrint('Check phone verified error: $e');
      return false;
    }
  }

  /// Get current user's phone verification status
  Future<bool> get currentUserPhoneVerified async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return false;
    return await isPhoneVerified(user.id);
  }

  /// Send SMS verification code using Supabase's built-in SMS
  /// This uses the phone confirmation flow from auth
  Future<void> sendSMSCode(String phoneNumber) async {
    try {
      await _client.auth.signInWithOtp(
        phone: phoneNumber,
      );
      debugPrint('SMS verification code sent to: $phoneNumber');
    } on AuthException catch (e) {
      debugPrint('Send SMS AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Send SMS error: $e');
      rethrow;
    }
  }

  /// Verify SMS code for phone authentication
  /// This verifies the OTP sent via SMS
  Future<AuthResponse> verifySMSCode({
    required String phoneNumber,
    required String code,
    String? role,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phoneNumber,
        token: code,
        type: OtpType.sms,
      );

      // Update profile with verified timestamp
      final user = response.user;
      if (user != null) {
        await markPhoneVerified(user.id);

        // Also update phone number if not set
        await _client.from('user_profiles').upsert({
          'id': user.id,
          'phone': phoneNumber,
          'phone_verified_at': DateTime.now().toIso8601String(),
          if (role != null) 'role': role,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('SMS code verified for: $phoneNumber');
      return response;
    } on AuthException catch (e) {
      debugPrint('Verify SMS AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Verify SMS error: $e');
      rethrow;
    }
  }

  /// Legacy: Get phone factors (for backwards compatibility)
  /// Note: Supabase SMS MFA uses totp factor type internally
  Future<List<Map<String, dynamic>>> getPhoneFactors() async {
    final allFactors = await getEnrolledFactors();
    // Filter factors that are likely phone factors based on friendly name
    return allFactors.where((f) {
      final friendlyName = f['friendly_name'] as String?;
      return friendlyName?.toLowerCase().contains('phone') ?? false;
    }).toList();
  }

  /// Legacy: Unenroll phone factor (for backwards compatibility)
  Future<void> unenrollPhone(String factorId) async {
    await unenrollFactor(factorId);
  }
}
