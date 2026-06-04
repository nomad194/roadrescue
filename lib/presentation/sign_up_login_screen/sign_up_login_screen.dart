import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import 'package:roadrescue_shared/services/auth_social_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/mfa_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import './widgets/auth_form_widget.dart';
import './widgets/auth_header_widget.dart';
import './widgets/demo_credentials_widget.dart';
import './widgets/expandable_email_signup_widget.dart';
import './widgets/social_login_widget.dart';

class SignUpLoginScreen extends StatefulWidget {
  final String? fixedRole;

  const SignUpLoginScreen({super.key, this.fixedRole});

  @override
  State<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends State<SignUpLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  String _selectedRole = 'customer';
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDemoCredentials = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.fixedRole != null) {
      _selectedRole = widget.fixedRole!;
    }
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _loadAppSettings();

    // If already signed in, redirect immediately
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _redirectByRole();
        } on PostgrestException catch (e) {
          if (e.code == '401' || e.message.toLowerCase().contains('jwt expired')) {
            await Supabase.instance.client.auth.signOut();
          }
        } catch (_) {
          // Stay on login screen for other errors
        }
      });
    }

    // Listen for auth state changes (handles OAuth browser redirect callback)
    _authSubscription = SupabaseService.instance.authStateChanges.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        try {
          await _redirectByRole();
        } on PostgrestException catch (e) {
          if (e.code == '401' || e.message.toLowerCase().contains('jwt expired')) {
            await Supabase.instance.client.auth.signOut();
          }
        } catch (_) {
          // Stay on login screen for other errors
        }
      }
    });
  }

  Future<void> _loadAppSettings() async {
    final demo = await SupabaseService.instance.getAppSetting('show_demo_credentials');
    if (mounted) {
      setState(() {
        _showDemoCredentials = demo == 'true';
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  Future<void> _redirectByRole() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    // Ensure profile exists first (critical for new social-auth users)
    final isNew = await AuthSocialService.instance.handlePostSocialAuth(user);

    // Fetch profile to get role and verification status
    final profile = await SupabaseService.instance.getUserProfile(user.id);
    final role =
        profile?['role'] as String? ??
        user.userMetadata?['role'] as String? ??
        'customer';
    final phone = profile?['phone'] as String? ?? '';

    if (!mounted) return;

    // New social-auth users (or users with missing phone) go to completion screens
    if (isNew || phone.isEmpty) {
      if (role == 'provider') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.completeProviderProfileScreen,
          (r) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.completeCustomerProfileScreen,
          (r) => false,
        );
      }
      return;
    }

    // Check phone verification first
    final isPhoneVerified = await MfaService.instance.isPhoneVerified(user.id);

    if (!mounted) return;

    if (!isPhoneVerified) {
      // Redirect to phone verification screen first
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.phoneVerificationScreen,
        (r) => false,
      );
      return;
    }

    // Phone is verified, proceed to role-based redirect
    if (role == 'provider') {
      // Check if provider documents are verified; if not, redirect to documents screen
      final isVerified = profile?['is_verified'] as bool? ?? false;
      Navigator.pushNamedAndRemoveUntil(
        context,
        isVerified ? AppRoutes.jobRequestsScreen : AppRoutes.providerDocumentsScreen,
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

  Future<void> _onSubmit({
    required String email,
    required String password,
    String fullName = '',
    String phone = '',
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await SupabaseService.instance.signIn(email: email, password: password);
      } else {
        await SupabaseService.instance.signUp(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
          role: _selectedRole,
        );
      }
      await _redirectByRole();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _translateAuthError(e.message));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = LocalizationService.instance.t('generic_error'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateAuthError(String message) {
    final l = LocalizationService.instance;
    // Map common Supabase auth errors to translation keys
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('invalid login credentials')) {
      return l.t('invalid_credentials');
    }
    if (lowerMessage.contains('email not confirmed')) {
      return l.t('email_not_confirmed');
    }
    if (lowerMessage.contains('user already registered')) {
      return l.t('user_already_exists');
    }
    if (lowerMessage.contains('password')) {
      return l.t('password_requirements');
    }
    // Return original if no translation found
    return message;
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final themeService = ThemeService.instance;
    final role = widget.fixedRole ?? _selectedRole;

    final bgColor = themeService.getBgColorFor(role: role, isLogin: _isLogin);
    final bgImageUrl = themeService.getBgImageUrlFor(role: role, isLogin: _isLogin);

    return Scaffold(
      backgroundColor: bgColor ?? Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background layer fills entire screen
          if (bgImageUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(bgImageUrl),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                ),
              ),
            ),
          // Content layer with SafeArea
          SafeArea(
            child: _isTablet ? _buildTabletLayout(size) : _buildPhoneLayout(size),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(Size size) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          AuthHeaderWidget(isLogin: _isLogin, role: _selectedRole),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  if (_isLogin)
                    AuthFormWidget(
                      isLogin: _isLogin,
                      isLoading: _isLoading,
                      selectedRole: _selectedRole,
                      onSubmit: _onSubmit,
                    )
                  else
                    ExpandableEmailSignupWidget(
                      isLoading: _isLoading,
                      selectedRole: _selectedRole,
                      onSubmit: _onSubmit,
                    ),
                  const SizedBox(height: 16),
                  _buildToggleModeRow(),
                  const SizedBox(height: 20),
                  SocialLoginWidget(
                    selectedRole: _selectedRole,
                    isSignUp: !_isLogin,
                  ),
                  if (widget.fixedRole == null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        shadowColor: Colors.black.withAlpha(100),
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.providerLoginScreen,
                            ),
                            icon: const Icon(
                              Icons.build_circle_rounded,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            label: Text(
                              LocalizationService.instance.t('provider_login'),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (widget.fixedRole == 'provider') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        shadowColor: Colors.black.withAlpha(100),
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.directions_car_rounded,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                            label: Text(
                              LocalizationService.instance.t('driver_login'),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_showDemoCredentials) ...[
                    const SizedBox(height: 24),
                    DemoCredentialsWidget(selectedRole: _selectedRole),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                AuthHeaderWidget(isLogin: _isLogin, role: _selectedRole),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(_errorMessage!),
                          const SizedBox(height: 12),
                        ],
                        if (_isLogin)
                          AuthFormWidget(
                            isLogin: _isLogin,
                            isLoading: _isLoading,
                            selectedRole: _selectedRole,
                            onSubmit: _onSubmit,
                          )
                        else
                          ExpandableEmailSignupWidget(
                            isLoading: _isLoading,
                            selectedRole: _selectedRole,
                            onSubmit: _onSubmit,
                          ),
                        const SizedBox(height: 16),
                        _buildToggleModeRow(),
                        const SizedBox(height: 20),
                        SocialLoginWidget(
                          selectedRole: _selectedRole,
                          isSignUp: !_isLogin,
                        ),
                        if (widget.fixedRole == null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(12),
                              shadowColor: Colors.black.withAlpha(100),
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.providerLoginScreen,
                                  ),
                                  icon: const Icon(
                                    Icons.build_circle_rounded,
                                    size: 16,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    LocalizationService.instance.t('provider_login'),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (widget.fixedRole == 'provider') ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(12),
                              shadowColor: Colors.black.withAlpha(100),
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.directions_car_rounded,
                                    size: 16,
                                    color: AppTheme.primary,
                                  ),
                                  label: Text(
                                    LocalizationService.instance.t('driver_login'),
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_showDemoCredentials) ...[
                          const SizedBox(height: 24),
                          DemoCredentialsWidget(selectedRole: _selectedRole),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppTheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.error,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleModeRow() {
    final l = LocalizationService.instance;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? l.t('dont_have_account') : l.t('already_have_account'),
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            _isLogin ? l.t('sign_up') : l.t('sign_in'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
