import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class SocialLoginWidget extends StatelessWidget {
  const SocialLoginWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(height: 1, color: AppTheme.outlineVariant),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                LocalizationService.instance.t('or_continue_with'),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 1, color: AppTheme.outlineVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata_rounded,
                iconColor: const Color(0xFFEA4335),
                onTap: () {
                  // Google Sign-In placeholder
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Facebook',
                icon: Icons.facebook_rounded,
                iconColor: const Color(0xFF1877F2),
                onTap: () {
                  // Facebook Sign-In placeholder
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                icon: Icons.apple_rounded,
                iconColor: AppTheme.onSurface,
                onTap: () {
                  // Apple Sign-In placeholder
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.outline, width: 1.2),
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 22, color: widget.iconColor),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
