import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';

class DemoCredentialsWidget extends StatefulWidget {
  final String selectedRole;

  const DemoCredentialsWidget({super.key, required this.selectedRole});

  @override
  State<DemoCredentialsWidget> createState() => _DemoCredentialsWidgetState();
}

class _DemoCredentialsWidgetState extends State<DemoCredentialsWidget> {
  String? _email;
  String? _password;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final isProvider = widget.selectedRole == 'provider';
    final settings = await SupabaseService.instance.getAppSettings([
      isProvider ? 'demo_provider_email' : 'demo_customer_email',
      isProvider ? 'demo_provider_password' : 'demo_customer_password',
    ]);
    if (mounted) {
      setState(() {
        _email = settings[isProvider ? 'demo_provider_email' : 'demo_customer_email'];
        _password = settings[isProvider ? 'demo_provider_password' : 'demo_customer_password'];
        _loaded = true;
      });
    }
  }

  String get _roleLabel {
    final l = LocalizationService.instance;
    switch (widget.selectedRole) {
      case 'provider':
        return l.t('provider');
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
    if (!_loaded) return const SizedBox.shrink();
    final email = _email;
    final password = _password;
    if (email == null || password == null) return const SizedBox.shrink();

    final l = LocalizationService.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryContainer,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${l.t('demo_credentials')} ($_roleLabel)',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CredentialRow(
            label: l.t('email'),
            value: email,
            onCopy: () => _copyToClipboard(context, email, l.t('email')),
          ),
          const SizedBox(height: 6),
          _CredentialRow(
            label: l.t('password'),
            value: password,
            onCopy: () => _copyToClipboard(context, password, l.t('password')),
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
