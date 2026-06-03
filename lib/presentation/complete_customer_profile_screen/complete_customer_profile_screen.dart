import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

import '../../routes/app_routes.dart';

class CompleteCustomerProfileScreen extends StatefulWidget {
  const CompleteCustomerProfileScreen({super.key});

  @override
  State<CompleteCustomerProfileScreen> createState() =>
      _CompleteCustomerProfileScreenState();
}

class _CompleteCustomerProfileScreenState
    extends State<CompleteCustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSocialData();
  }

  Future<void> _loadSocialData() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final profile = await SupabaseService.instance.getUserProfile(user.id);
    final metadata = user.userMetadata;

    if (mounted) {
      setState(() {
        _nameController.text = profile?['full_name'] as String? ??
            metadata?['full_name'] as String? ??
            '';
        _emailController.text = profile?['email'] as String? ??
            user.email ??
            '';
        _phoneController.text = profile?['phone'] as String? ??
            metadata?['phone'] as String? ??
            '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await SupabaseService.instance.updateProfile(user.id, {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'customer',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.phoneVerificationScreen,
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('complete_profile'),
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.t('complete_profile_desc'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.error.withAlpha(80),
                          ),
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
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.error,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildLabel(l.t('full_name')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Marcus Johnson',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        prefixIconColor: AppTheme.muted,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.t('full_name_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(l.t('email')),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        prefixIconColor: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppTheme.primary.withAlpha(100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                          shadowColor: AppTheme.primary.withAlpha(120),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l.t('continue'),
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
}
