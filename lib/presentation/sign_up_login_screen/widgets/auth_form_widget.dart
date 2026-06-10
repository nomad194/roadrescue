import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';

import '../../../routes/app_routes.dart';

class AuthFormWidget extends StatefulWidget {
  final bool isLogin;
  final bool isLoading;
  final String selectedRole;
  final Future<void> Function({
    required String email,
    required String password,
    String fullName,
    String phone,
  })
  onSubmit;

  const AuthFormWidget({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.selectedRole,
    required this.onSubmit,
  });

  @override
  State<AuthFormWidget> createState() => _AuthFormWidgetState();
}

class _AuthFormWidgetState extends State<AuthFormWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isLogin) ...[
            _buildLabel(l.t('full_name')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l.t('name_hint'),
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                prefixIconColor: AppTheme.muted,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l.t('full_name_required');
                }
                if (v.trim().length < 2) {
                  return l.t('name_too_short');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          _buildLabel(l.t('email')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.selectedRole == 'customer'
                  ? l.t('email_example')
                  : l.t('email_example_provider'),
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              prefixIconColor: AppTheme.muted,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l.t('email_required');
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(v.trim())) {
                return l.t('invalid_email');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!widget.isLogin) ...[
            _buildLabel(l.t('phone')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: l.t('phone_hint'),
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                prefixIconColor: AppTheme.muted,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l.t('phone_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          _buildLabel(l.t('password')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: l.t('password_hint'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              prefixIconColor: AppTheme.muted,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppTheme.muted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l.t('password_required');
              if (v.length < 8) return l.t('password_too_short');
              final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(v);
              final hasNumber = RegExp(r'[0-9]').hasMatch(v);
              if (!hasLetter || !hasNumber) {
                return l.t('password_must_contain_letter_and_number');
              }
              return null;
            },
          ),
          if (!widget.isLogin) ...[
            const SizedBox(height: 12),
            _buildLabel(l.t('confirm_password')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: l.t('password_hint'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                prefixIconColor: AppTheme.muted,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppTheme.muted,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l.t('password_required');
                if (v != _passwordController.text) {
                  return l.t('passwords_do_not_match');
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          if (widget.isLogin) ...[
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(color: AppTheme.outline),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.t('remember_me'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.forgotPasswordScreen,
                  ),
                  child: Text(
                    l.t('forgot_password'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 8),
          if (!widget.isLogin) ...[
            _buildTermsRow(l),
            const SizedBox(height: 20),
          ],
          _buildSubmitButton(l),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTermsRow(LocalizationService l) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.manrope(
          fontSize: 12,
          color: AppTheme.muted,
          height: 1.5,
        ),
        children: [
          TextSpan(text: l.t('by_signing_up')),
          TextSpan(
            text: l.t('terms_of_service'),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          TextSpan(text: l.t('and')),
          TextSpan(
            text: l.t('privacy_policy'),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> _resolveShadow(String shadow, Color glowColor) {
    if (shadow == 'none') return [];
    final alpha = switch (shadow) {
      'light' => 40,
      'heavy' => 120,
      _ => 80,
    };
    final blur = switch (shadow) {
      'light' => 8.0,
      'heavy' => 24.0,
      _ => 16.0,
    };
    final spread = switch (shadow) {
      'light' => 0.0,
      'heavy' => 2.0,
      _ => 1.0,
    };
    return [BoxShadow(color: glowColor.withAlpha(alpha), blurRadius: blur, spreadRadius: spread)];
  }

  Widget _buildSubmitButton(LocalizationService l) {
    final themeService = ThemeService.instance;
    final bgColor = themeService.getMainButtonBgColorFor(role: widget.selectedRole, isLogin: widget.isLogin);
    final textColor = themeService.getMainButtonTextColorFor(role: widget.selectedRole, isLogin: widget.isLogin);
    final glowColor = themeService.getMainButtonGlowColorFor(role: widget.selectedRole, isLogin: widget.isLogin);
    final borderRadius = themeService.getMainButtonBorderRadiusFor(role: widget.selectedRole, isLogin: widget.isLogin);
    final shadow = themeService.getMainButtonShadowFor(role: widget.selectedRole, isLogin: widget.isLogin);
    final animation = themeService.getMainButtonAnimationFor(role: widget.selectedRole, isLogin: widget.isLogin);

    Widget button = ElevatedButton(
      onPressed: widget.isLoading ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        disabledBackgroundColor: bgColor.withAlpha(100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: widget.isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
            )
          : Text(
              widget.isLogin ? l.t('sign_in') : l.t('create_account'),
              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
            ),
    );

    button = Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: _resolveShadow(shadow, glowColor ?? bgColor),
      ),
      child: button,
    );

    if (animation == 'pulse') {
      button = AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = 1.0 + (_animController.value * 0.02);
          return Transform.scale(scale: scale, child: child);
        },
        child: button,
      );
    } else if (animation == 'fade') {
      button = AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final opacity = 0.9 + (_animController.value * 0.1);
          return Opacity(opacity: opacity, child: child);
        },
        child: button,
      );
    }

    return button;
  }
}
