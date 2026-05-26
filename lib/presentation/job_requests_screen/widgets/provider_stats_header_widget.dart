import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class ProviderStatsHeaderWidget extends StatelessWidget {
  final List<dynamic> jobs;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final String providerName;
  final String locationLabel;

  const ProviderStatsHeaderWidget({
    super.key,
    required this.jobs,
    required this.selectedStatus,
    required this.onStatusChanged,
    this.providerName = '',
    this.locationLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(64), blurRadius: 16, offset: const Offset(0, 5))],
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
                    Text('${l.t('good_morning')}${providerName.isNotEmpty ? ', ${providerName.split(' ').first}' : ''}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(locationLabel.isNotEmpty ? '${l.t('available_at')} $locationLabel' : l.t('available'), style: GoogleFonts.manrope(fontSize: 11, color: Colors.white.withAlpha(204))),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(77))),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 4),
                        Text('4.9', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('\$${todayEarnings.toStringAsFixed(0)} ${l.t('today')}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTab(label: l.t('tab_new'), value: '$newCount', isActive: selectedStatus == 'new', onTap: () => onStatusChanged('new'), color: const Color(0xFFFBBF24)),
              _StatDivider(),
              _StatTab(label: l.t('tab_quoted'), value: '$quotedCount', isActive: selectedStatus == 'quoted', onTap: () => onStatusChanged('quoted'), color: const Color(0xFF93C5FD)),
              _StatDivider(),
              _StatTab(label: l.t('tab_active'), value: '$activeCount', isActive: selectedStatus == 'active', onTap: () => onStatusChanged('active'), color: const Color(0xFF4ADE80)),
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

  const _StatTab({required this.label, required this.value, required this.isActive, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: isActive ? color : Colors.white.withAlpha(200))),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.manrope(fontSize: 9, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? Colors.white : Colors.white.withAlpha(160))),
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
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: Colors.white.withAlpha(40));
  }
}
