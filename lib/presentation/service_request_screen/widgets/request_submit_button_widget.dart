import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class RequestSubmitButtonWidget extends StatefulWidget {
  final bool isSubmitting;
  final bool isEnabled;
  final VoidCallback onSubmit;

  const RequestSubmitButtonWidget({
    super.key,
    required this.isSubmitting,
    required this.isEnabled,
    required this.onSubmit,
  });

  @override
  State<RequestSubmitButtonWidget> createState() =>
      _RequestSubmitButtonWidgetState();
}

class _RequestSubmitButtonWidgetState extends State<RequestSubmitButtonWidget> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      children: [
        GestureDetector(
          onTapDown: widget.isEnabled
              ? (_) => setState(() => _scale = 0.97)
              : null,
          onTapUp: widget.isEnabled
              ? (_) {
                  setState(() => _scale = 1.0);
                  widget.onSubmit();
                }
              : null,
          onTapCancel: () => setState(() => _scale = 1.0),
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.isEnabled
                    ? const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.isEnabled ? null : AppTheme.outline,
                borderRadius: BorderRadius.circular(14),
                boxShadow: widget.isEnabled
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(89),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: widget.isEnabled
                                ? Colors.white
                                : AppTheme.muted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l.t('submit_request'),
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: widget.isEnabled
                                  ? Colors.white
                                  : AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 13, color: AppTheme.muted),
            const SizedBox(width: 5),
            Text(
              l.t('verified_providers_only'),
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
      ],
    );
  }
}
