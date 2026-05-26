import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routes/app_routes.dart';
import '../../../services/auth_social_service.dart';
import '../../../services/localization_service.dart';
import '../../../services/mfa_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// Social login widget with Google, Apple, and Facebook sign-in buttons
class SocialLoginWidget extends StatefulWidget {
  final String? selectedRole;

  const SocialLoginWidget({
    super.key,
    this.selectedRole,
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
      final response = await AuthSocialService.instance.signInWithGoogle();

      if (response.user != null && mounted) {
        // Update role if provided during signup
        if (widget.selectedRole != null) {
          await _updateUserRole(response.user!.id, widget.selectedRole!);
        }

        // Check phone verification and redirect
        await _redirectAfterLogin(response.user!.id);
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

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = 'apple';
    });

    try {
      final response = await AuthSocialService.instance.signInWithApple();

      if (response.user != null && mounted) {
        // Update role if provided during signup
        if (widget.selectedRole != null) {
          await _updateUserRole(response.user!.id, widget.selectedRole!);
        }

        // Check phone verification and redirect
        await _redirectAfterLogin(response.user!.id);
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
      debugPrint('Error updating role: $e');
    }
  }

  Future<void> _redirectAfterLogin(String userId) async {
    // Get role first to check if admin (admins exempt from phone verification)
    final profile = await SupabaseService.instance.client
        .from('user_profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    final role = profile?['role'] as String? ?? 'customer';

    // Check if phone is verified (admins are exempt)
    if (role != 'admin') {
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
    }

    if (!mounted) return;

    if (role == 'provider') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.providerDocumentsScreen,
        (r) => false,
      );
    } else if (role == 'admin') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminDashboardScreen,
        (r) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.serviceRequestScreen,
        (r) => false,
      );
    }
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
                l.t('or_continue_with'),
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
        // Social buttons
        if (_showApple) ...[
          _buildSocialButton(
            provider: 'apple',
            label: l.t('sign_in_with_apple'),
            onPressed: _handleAppleSignIn,
            icon: Icons.apple,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
        ],
        if (_showGoogle) ...[
          _buildSocialButton(
            provider: 'google',
            label: l.t('sign_in_with_google'),
            onPressed: _handleGoogleSignIn,
            icon: Icons.g_mobiledata_rounded,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            borderColor: AppTheme.outline,
          ),
          const SizedBox(height: 12),
        ],
        if (_showFacebook) ...[
          _buildSocialButton(
            provider: 'facebook',
            label: l.t('sign_in_with_facebook'),
            onPressed: _handleFacebookSignIn,
            icon: Icons.facebook,
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButton({
    required String provider,
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
  }) {
    final isLoading = _isLoading && _loadingProvider == provider;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor != null
                ? BorderSide(color: borderColor)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
