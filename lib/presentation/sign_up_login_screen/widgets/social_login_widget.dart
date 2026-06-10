import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routes/app_routes.dart';
import 'package:roadrescue_shared/services/auth_social_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/mfa_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

/// Social login widget with Google, Apple, and Facebook sign-in buttons
class SocialLoginWidget extends StatefulWidget {
  final String? selectedRole;
  final bool isSignUp;

  const SocialLoginWidget({
    super.key,
    this.selectedRole,
    this.isSignUp = false,
  });

  @override
  State<SocialLoginWidget> createState() => _SocialLoginWidgetState();
}

class _SocialLoginWidgetState extends State<SocialLoginWidget> {
  bool _isLoading = false;
  String? _loadingProvider;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = 'google';
    });

    try {
      // Persist role so profile is created with correct role after OAuth redirect
      if (widget.selectedRole != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_social_role', widget.selectedRole!);
      }
      // Launches browser OAuth flow - auth state change handled by sign_up_login_screen
      await AuthSocialService.instance.signInWithGoogle();
      // Loading state cleared when user returns from browser or on error
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError(LocalizationService.instance.t('generic_error'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = 'apple';
    });

    try {
      final response = await AuthSocialService.instance.signInWithApple();

      if (response.user != null && mounted) {
        // Ensure profile exists and check if user is new
        final isNew = await AuthSocialService.instance.handlePostSocialAuth(response.user);

        // Update role if provided during signup
        if (widget.selectedRole != null) {
          await _updateUserRole(response.user!.id, widget.selectedRole!);
        }

        // Redirect based on new vs returning user
        await _redirectAfterLogin(response.user!.id, isNew: isNew);
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError(LocalizationService.instance.t('generic_error'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = 'facebook';
    });

    try {
      // Persist role so profile is created with correct role after OAuth redirect
      if (widget.selectedRole != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_social_role', widget.selectedRole!);
      }
      // Facebook uses OAuth redirect flow
      await AuthSocialService.instance.signInWithFacebook();

      // Note: For Facebook OAuth, the app will be redirected back
      // The auth state change listener should handle the rest
      // This is handled in the main app via onAuthStateChange

    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError(LocalizationService.instance.t('generic_error'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      await SupabaseService.instance.client
          .from('user_profiles')
          .update({'role': role})
          .eq('id', userId);
    } catch (e) {
    }
  }

  Future<void> _redirectAfterLogin(String userId, {bool isNew = false}) async {
    final profile = await SupabaseService.instance.client
        .from('user_profiles')
        .select('role, phone')
        .eq('id', userId)
        .maybeSingle();

    final role = profile?['role'] as String? ?? 'customer';
    final phone = profile?['phone'] as String? ?? '';

    if (!mounted) return;

    // Block providers — they must use the provider_app
    if (role == 'provider') {
      await SupabaseService.instance.signOut();
      if (mounted) {
        _showError(LocalizationService.instance.t('wrong_role_provider'));
      }
      return;
    }

    // New social-auth users (or users with missing phone) go to customer completion screen
    if (isNew || phone.isEmpty) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.completeCustomerProfileScreen,
        (r) => false,
      );
      return;
    }

    // Check if phone is verified
    final isPhoneVerified = await MfaService.instance.isPhoneVerified(userId);

    if (!mounted) return;

    if (!isPhoneVerified) {
      // Redirect to phone verification
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.phoneVerificationScreen,
        (r) => false,
      );
      return;
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.serviceRequestScreen,
      (r) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool get _showGoogle => AuthSocialService.instance.isGoogleSignInAvailable;
  bool get _showApple => AuthSocialService.instance.isAppleSignInAvailable;
  bool get _showFacebook => AuthSocialService.instance.isFacebookSignInAvailable;

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    // Check if any social providers are available
    if (!_showGoogle && !_showApple && !_showFacebook) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Divider with "or continue with" text
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppTheme.outlineVariant,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.isSignUp ? l.t('or_create_with') : l.t('or_continue_with'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppTheme.outlineVariant,
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Social buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_showApple)
              _buildRoundSocialButton(
                provider: 'apple',
                onPressed: _handleAppleSignIn,
                icon: Icons.apple,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            if (_showApple && _showGoogle) const SizedBox(width: 16),
            if (_showGoogle)
              _buildRoundSocialButton(
                provider: 'google',
                onPressed: _handleGoogleSignIn,
                icon: Icons.g_mobiledata_rounded,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                borderColor: AppTheme.outline,
              ),
            if ((_showGoogle && _showFacebook) || (_showApple && _showFacebook))
              const SizedBox(width: 16),
            if (_showFacebook)
              _buildRoundSocialButton(
                provider: 'facebook',
                onPressed: _handleFacebookSignIn,
                icon: Icons.facebook,
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundSocialButton({
    required String provider,
    required VoidCallback onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
  }) {
    final isLoading = _isLoading && _loadingProvider == provider;

    return InkWell(
      onTap: isLoading ? null : onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: foregroundColor,
                ),
              )
            : Icon(icon, size: 24, color: foregroundColor),
      ),
    );
  }
}
