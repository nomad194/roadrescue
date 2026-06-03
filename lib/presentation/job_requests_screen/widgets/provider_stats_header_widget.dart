import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';

class ProviderStatsHeaderWidget extends StatelessWidget {
  final List<dynamic> jobs;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final String providerName;
  final String locationLabel;
  final bool isAvailable;
  final VoidCallback? onAvailabilityToggle;
  final bool isLoadingAvailability;
  final double averageRating;
  final bool isLoadingRating;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfilePressed;

  const ProviderStatsHeaderWidget({
    super.key,
    required this.jobs,
    required this.selectedStatus,
    required this.onStatusChanged,
    this.providerName = '',
    this.locationLabel = '',
    this.isAvailable = true,
    this.onAvailabilityToggle,
    this.isLoadingAvailability = false,
    this.averageRating = 0.0,
    this.isLoadingRating = false,
    this.onNotificationPressed,
    this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final ts = ThemeService.instance;
    int newCount = 0;
    int quotedCount = 0;
    int activeCount = 0;
    double todayEarnings = 0;

    for (final j in jobs) {
      final status = j.status ?? '';
      final value = (j.estimatedValue as num?)?.toDouble() ?? 0.0;
      if (status == 'new') newCount++;
      if (status == 'quoted') quotedCount++;
      if (status == 'accepted' || status == 'en_route' || status == 'awaiting_confirmation' || status == 'awaiting_reconfirmation' || status == 'disputed') {
        activeCount++;
      }
      if (status == 'completed') {
        todayEarnings += value;
      }
    }

    final headerOpacity = ts.providerMainHeaderOpacity;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ts.providerMainHeaderGradientStart.withAlpha((255 * headerOpacity).round()),
            ts.providerMainHeaderGradientEnd.withAlpha((255 * headerOpacity).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: ts.providerMainHeaderGradientStart.withAlpha(64), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.t('good_morning')}${providerName.isNotEmpty ? ', ${providerName.split(' ').first}' : ''}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: ts.providerMainHeaderTextColor)),
                    const SizedBox(height: 2),
                    Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isAvailable ? ts.providerMainAvailableColor : ts.providerMainUnavailableColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable ? l.t('available') : l.t('unavailable'),
                        style: GoogleFonts.manrope(fontSize: 11, color: ts.providerMainHeaderTextColor.withAlpha(204)),
                      ),
                      const SizedBox(width: 8),
                      // Availability Toggle
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ts.providerMainHeaderTextColor.withAlpha(40)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 24,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Switch(
                                  value: isAvailable,
                                  onChanged: isLoadingAvailability ? null : (_) => onAvailabilityToggle?.call(),
                                  activeThumbColor: ts.providerMainAvailableColor,
                                  inactiveThumbColor: ts.providerMainUnavailableColor,
                                  activeTrackColor: Colors.white.withAlpha(100),
                                  inactiveTrackColor: Colors.white.withAlpha(50),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: onNotificationPressed,
                        bgColor: ts.providerMainHeaderIconBtnBg,
                        iconColor: ts.providerMainHeaderIconBtnIcon,
                      ),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.person_outline_rounded,
                        onPressed: onProfilePressed,
                        bgColor: ts.providerMainHeaderIconBtnBg,
                        iconColor: ts.providerMainHeaderIconBtnIcon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ts.providerMainHeaderTextColor.withAlpha(38), borderRadius: BorderRadius.circular(20), border: Border.all(color: ts.providerMainHeaderTextColor.withAlpha(77))),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 4),
                        Text(
                          isLoadingRating ? '...' : averageRating.toStringAsFixed(1),
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: ts.providerMainHeaderTextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('\$${todayEarnings.toStringAsFixed(0)} ${l.t('today')}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: ts.providerMainHeaderTextColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTab(label: l.t('tab_new'), value: '$newCount', isActive: selectedStatus == 'new', onTap: () => onStatusChanged('new'), color: const Color(0xFFFBBF24), headerTextColor: ts.providerMainHeaderTextColor),
              _StatDivider(dividerColor: ts.providerMainHeaderTextColor),
              _StatTab(label: l.t('tab_quoted'), value: '$quotedCount', isActive: selectedStatus == 'quoted', onTap: () => onStatusChanged('quoted'), color: const Color(0xFF93C5FD), headerTextColor: ts.providerMainHeaderTextColor),
              _StatDivider(dividerColor: ts.providerMainHeaderTextColor),
              _StatTab(label: l.t('tab_active'), value: '$activeCount', isActive: selectedStatus == 'active', onTap: () => onStatusChanged('active'), color: const Color(0xFF4ADE80), headerTextColor: ts.providerMainHeaderTextColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTab extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;
  final Color headerTextColor;

  const _StatTab({required this.label, required this.value, required this.isActive, required this.onTap, required this.color, required this.headerTextColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? headerTextColor.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: isActive ? color : headerTextColor.withAlpha(200))),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? headerTextColor : headerTextColor.withAlpha(160))),
              if (isActive) ...[
                const SizedBox(height: 4),
                Container(width: 12, height: 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color dividerColor;
  const _StatDivider({required this.dividerColor});
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: dividerColor.withAlpha(40));
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color bgColor;
  final Color iconColor;

  const _HeaderIconButton({required this.icon, this.onPressed, required this.bgColor, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: iconColor.withAlpha(50)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
      ),
    );
  }
}
