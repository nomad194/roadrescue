import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import './widgets/auth_form_widget.dart';
import './widgets/auth_header_widget.dart';
import './widgets/demo_credentials_widget.dart';
import './widgets/role_toggle_widget.dart';
import './widgets/social_login_widget.dart';

class SignUpLoginScreen extends StatefulWidget {
  const SignUpLoginScreen({super.key});

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
  bool _showRoleSwitcher = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirectByRole());
    }
  }

  Future<void> _loadAppSettings() async {
    final demo = await SupabaseService.instance.getAppSetting('show_demo_credentials');
    final switcher = await SupabaseService.instance.getAppSetting('show_role_switcher');
    if (mounted) {
      setState(() {
        _showDemoCredentials = demo == 'true';
        _showRoleSwitcher = switcher != 'false';
      });
    }
  }

  @override
  void dispose() {
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

  void _onRoleChanged(String role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
    });
  }

  Future<void> _redirectByRole() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    // Fetch profile to get role
    final profile = await SupabaseService.instance.getUserProfile(user.id);
    final role =
        profile?['role'] as String? ??
        user.userMetadata?['role'] as String? ??
        'customer';

    if (!mounted) return;
    if (role == 'provider') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.jobRequestsScreen,
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
        setState(() => _errorMessage = e.message);
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

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isTablet ? _buildTabletLayout(size) : _buildPhoneLayout(size),
      ),
    );
  }

  Widget _buildPhoneLayout(Size size) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          AuthHeaderWidget(isLogin: _isLogin),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (_showRoleSwitcher)
                    RoleToggleWidget(
                      selectedRole: _selectedRole,
                      onRoleChanged: _onRoleChanged,
                    ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(_errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  AuthFormWidget(
                    isLogin: _isLogin,
                    isLoading: _isLoading,
                    selectedRole: _selectedRole,
                    onSubmit: _onSubmit,
                  ),
                  const SizedBox(height: 16),
                  _buildToggleModeRow(),
                  const SizedBox(height: 20),
                  const SocialLoginWidget(),
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
                AuthHeaderWidget(isLogin: _isLogin),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        if (_showRoleSwitcher)
                          RoleToggleWidget(
                            selectedRole: _selectedRole,
                            onRoleChanged: _onRoleChanged,
                          ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(_errorMessage!),
                          const SizedBox(height: 12),
                        ],
                        AuthFormWidget(
                          isLogin: _isLogin,
                          isLoading: _isLoading,
                          selectedRole: _selectedRole,
                          onSubmit: _onSubmit,
                        ),
                        const SizedBox(height: 16),
                        _buildToggleModeRow(),
                        const SizedBox(height: 20),
                        const SocialLoginWidget(),
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
