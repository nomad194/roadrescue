import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';

class TopNavBar extends StatelessWidget {
  final String? cityName;
  final VoidCallback? onNotificationTap;

  const TopNavBar({
    super.key,
    this.cityName,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Location
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    cityName ?? l.t('location_not_set'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Right: Notification only
          GestureDetector(
            onTap: onNotificationTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: AppTheme.onSurface,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '3',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
