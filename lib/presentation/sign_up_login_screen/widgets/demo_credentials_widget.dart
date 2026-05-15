import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class DemoCredentialsWidget extends StatelessWidget {
  final String selectedRole;

  const DemoCredentialsWidget({super.key, required this.selectedRole});

  String get _email {
    switch (selectedRole) {
      case 'provider':
        return 'provider.demo@roadrescue.com';
      case 'admin':
        return 'admin@roadrescue.com';
      default:
        return 'demo.driver@roadrescue.com';
    }
  }

  String get _password {
    switch (selectedRole) {
      case 'provider':
        return 'Provider@2026';
      case 'admin':
        return 'Admin@2026';
      default:
        return 'Driver@2026';
    }
  }

  String get _roleLabel {
    final l = LocalizationService.instance;
    switch (selectedRole) {
      case 'provider':
        return l.t('provider');
      case 'admin':
        return l.t('admin');
      default:
        return l.t('driver');
    }
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    final l = LocalizationService.instance;
    Clipboard.setData(ClipboardData(text: value));
    Fluttertoast.showToast(
      msg: '$label ${l.t('copied_to_clipboard')}',
      backgroundColor: AppTheme.onSurface,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedRole == 'admin'
            ? AppTheme.warningContainer.withAlpha(180)
            : AppTheme.primaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedRole == 'admin'
              ? AppTheme.warningContainer
              : AppTheme.primaryContainer,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selectedRole == 'admin'
                    ? Icons.admin_panel_settings_outlined
                    : Icons.info_outline_rounded,
                size: 16,
                color: selectedRole == 'admin'
                    ? AppTheme.warning
                    : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${l.t('demo_credentials')} ($_roleLabel)',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selectedRole == 'admin'
                      ? AppTheme.warning
                      : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CredentialRow(
            label: l.t('email'),
            value: _email,
            onCopy: () => _copyToClipboard(context, _email, l.t('email')),
          ),
          const SizedBox(height: 6),
          _CredentialRow(
            label: l.t('password'),
            value: _password,
            onCopy: () => _copyToClipboard(context, _password, l.t('password')),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CredentialRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.outline),
            ),
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.outline),
            ),
            child: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
