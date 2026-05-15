import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

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

class _AuthFormWidgetState extends State<AuthFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
              decoration: const InputDecoration(
                hintText: 'e.g. Marcus Johnson',
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
                  ? 'driver@example.com'
                  : 'provider@roadrescue.com',
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
          if (!widget.isLogin && widget.selectedRole != 'admin') ...[
            _buildLabel(l.t('phone')),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+1 (555) 000-0000',
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
              hintText: '••••••••',
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
              return null;
            },
          ),
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
                  onTap: () {},
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

  Widget _buildSubmitButton(LocalizationService l) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primary.withAlpha(100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.isLogin ? l.t('sign_in') : l.t('create_account'),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
