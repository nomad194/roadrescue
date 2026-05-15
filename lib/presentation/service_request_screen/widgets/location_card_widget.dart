import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class LocationCardWidget extends StatefulWidget {
  const LocationCardWidget({super.key});

  @override
  State<LocationCardWidget> createState() => _LocationCardWidgetState();
}

class _LocationCardWidgetState extends State<LocationCardWidget>
    with SingleTickerProviderStateMixin {
  // TODO: Replace with [Riverpod/Bloc] for production — use geolocator for real GPS
  bool _isDetecting = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isDetecting = false);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDetecting
              ? AppTheme.primary.withAlpha(102)
              : AppTheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isDetecting
                      ? AppTheme.primary.withValues(
                          alpha: 0.1 * _pulseAnimation.value + 0.05,
                        )
                      : AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isDetecting
                      ? Icons.gps_not_fixed_rounded
                      : Icons.gps_fixed_rounded,
                  size: 22,
                  color: _isDetecting ? AppTheme.primary : AppTheme.success,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDetecting
                      ? l.t('detecting_location')
                      : l.t('location_confirmed'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isDetecting ? AppTheme.primary : AppTheme.success,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isDetecting
                      ? l.t('gps_acquiring')
                      : '4721 Maple Ave, Austin, TX 78701',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (!_isDetecting) ...[
                  const SizedBox(height: 4),
                  Text(
                    '30.2672° N, 97.7431° W · Accuracy: ±8m',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_isDetecting)
            TextButton(
              onPressed: () {
                // TODO: Replace with [Riverpod/Bloc] for production — open map picker
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: Text(
                l.t('change'),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
