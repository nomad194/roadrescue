import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/localization_service.dart';
import '../../services/mfa_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  String? _errorMessage;
  int _attemptCount = 0;
  static const int _maxAttempts = 3;

  // Resend cooldown timer
  Timer? _resendTimer;
  int _resendSeconds = 0;
  static const int _resendCooldown = 60;

  String? _profilePhone;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    final profile = await SupabaseService.instance.getUserProfile(user.id);
    if (mounted) {
      setState(() {
        _profilePhone = profile?['phone'] as String?;
        _userRole = profile?['role'] as String? ??
            user.userMetadata?['role'] as String? ??
            'customer';

        // Pre-fill phone if available
        if (_profilePhone != null && _profilePhone!.isNotEmpty) {
          _phoneController.text = _profilePhone!;
        }
      });
    }

    // Check if already verified
    final isVerified = await MfaService.instance.isPhoneVerified(user.id);
    if (isVerified && mounted) {
      _redirectByRole();
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.signUpLoginScreen,
      (r) => false,
    );
  }

  void _redirectByRole() {
    if (!mounted) return;

    if (_userRole == 'provider') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.providerDocumentsScreen,
        (r) => false,
      );
    } else if (_userRole == 'admin') {
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

  void _startResendTimer() {
    _resendSeconds = _resendCooldown;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendSeconds > 0) {
            _resendSeconds--;
          } else {
            _resendTimer?.cancel();
          }
        });
      }
    });
  }

  Future<void> _sendCode() async {
    if (_attemptCount >= _maxAttempts) {
      setState(() {
        _errorMessage = LocalizationService.instance.t('max_attempts_exceeded');
      });
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = LocalizationService.instance.t('phone_required');
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      // Update phone in profile first
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        await MfaService.instance.updateProfilePhone(user.id, phone);
      }

      // Send SMS code
      await MfaService.instance.sendSMSCode(phone);

      if (mounted) {
        setState(() {
          _codeSent = true;
          _isSendingCode = false;
        });
        _startResendTimer();

        // Auto-focus first OTP field
        _otpFocusNodes[0].requestFocus();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSendingCode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = LocalizationService.instance.t('generic_error');
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_attemptCount >= _maxAttempts) {
      setState(() {
        _errorMessage = LocalizationService.instance.t('max_attempts_exceeded');
      });
      return;
    }

    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() {
        _errorMessage = LocalizationService.instance.t('enter_otp_code');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      await MfaService.instance.verifySMSCode(
        phoneNumber: phone,
        code: code,
      );

      _attemptCount++;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.t('phone_verified'),
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );

        // Redirect after short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _redirectByRole();
          }
        });
      }
    } on AuthException catch (e) {
      _attemptCount++;
      if (mounted) {
        setState(() {
          _errorMessage = e.message.contains('expired')
              ? LocalizationService.instance.t('code_expired')
              : e.message;
          _isLoading = false;
        });
        // Clear OTP fields on error
        for (var c in _otpControllers) {
          c.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      _attemptCount++;
      if (mounted) {
        setState(() {
          _errorMessage = LocalizationService.instance.t('generic_error');
          _isLoading = false;
        });
      }
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    // Auto-submit when all 6 digits entered
    if (index == 5 && value.length == 1) {
      final code = _otpControllers.map((c) => c.text).join();
      if (code.length == 6) {
        _verifyCode();
      }
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      _redirectToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          l.t('verify_phone'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              l.t('sign_out'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: isTablet ? _buildTabletLayout(l) : _buildPhoneLayout(l),
      ),
    );
  }

  Widget _buildPhoneLayout(LocalizationService l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l),
          const SizedBox(height: 32),
          _buildPhoneInput(l),
          const SizedBox(height: 24),
          if (_codeSent) ...[
            _buildOtpInput(l),
            const SizedBox(height: 24),
            _buildResendButton(l),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(_errorMessage!),
          ],
          const SizedBox(height: 32),
          _buildAttemptsIndicator(l),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(LocalizationService l) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(l),
              const SizedBox(height: 32),
              _buildPhoneInput(l),
              const SizedBox(height: 24),
              if (_codeSent) ...[
                _buildOtpInput(l),
                const SizedBox(height: 24),
                _buildResendButton(l),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(_errorMessage!),
              ],
              const SizedBox(height: 32),
              _buildAttemptsIndicator(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.t('verification_required'),
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.t('enter_phone_number'),
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: AppTheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('phone'),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_codeSent && !_isSendingCode,
          decoration: InputDecoration(
            hintText: '+1 (555) 123-4567',
            prefixIcon: const Icon(Icons.phone_outlined),
            filled: true,
            fillColor: _codeSent ? AppTheme.surfaceVariant.withAlpha(128) : AppTheme.surfaceVariant,
          ),
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSendingCode || _codeSent ? null : _sendCode,
          child: _isSendingCode
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_codeSent ? l.t('code_sent') : l.t('send_code')),
        ),
      ],
    );
  }

  Widget _buildOtpInput(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('enter_otp_code'),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
                onChanged: (value) => _onOtpChanged(index, value),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyCode,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l.t('verify')),
        ),
      ],
    );
  }

  Widget _buildResendButton(LocalizationService l) {
    final canResend = _resendSeconds == 0 && !_isSendingCode;

    return Center(
      child: TextButton(
        onPressed: canResend ? _sendCode : null,
        child: Text(
          canResend
              ? l.t('resend_code')
              : '${l.t('resend_code')} (${_resendSeconds}s)',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: canResend ? AppTheme.primary : AppTheme.muted,
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

  Widget _buildAttemptsIndicator(LocalizationService l) {
    final remaining = _maxAttempts - _attemptCount;
    final isLocked = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocked ? AppTheme.errorContainer : AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? Icons.lock_outline : Icons.info_outline,
            color: isLocked ? AppTheme.error : AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLocked
                  ? l.t('max_attempts_exceeded')
                  : '${l.t('max_limit')}: $remaining',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isLocked ? AppTheme.error : AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
