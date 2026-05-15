import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

// ignore: library_private_types_in_public_api
class ProviderStatsHeaderWidget extends StatelessWidget {
  final List<dynamic> jobs;

  const ProviderStatsHeaderWidget({super.key, required this.jobs});

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    // Compute stats from jobs
    int newJobsCount = 0;
    int quotedJobsCount = 0;
    int activeJobsCount = 0;
    double todayEarnings = 0;

    for (final j in jobs) {
      final status = j['job_status'] ?? '';
      final value = (j['quoted_price'] as num?)?.toDouble() ?? 0.0;
      if (status == 'pending') newJobsCount++;
      if (status == 'quoted') quotedJobsCount++;
      if (status == 'accepted' ||
          status == 'confirmed' ||
          status == 'en_route' ||
          status == 'in_progress') {
        activeJobsCount++;
      }
      if (status == 'completed') todayEarnings += value;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(64),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.t('good_morning')}, Carlos',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${l.t('available_at')} Austin, TX',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      ' (142)',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatItem(
                value: '$newJobsCount',
                label: l.t('new_jobs'),
                color: const Color(0xFFFBBF24),
              ),
              _StatDivider(),
              _StatItem(
                value: '$quotedJobsCount',
                label: l.t('quoted'),
                color: const Color(0xFF93C5FD),
              ),
              _StatDivider(),
              _StatItem(
                value: '$activeJobsCount',
                label: l.t('active'),
                color: const Color(0xFF4ADE80),
              ),
              _StatDivider(),
              _StatItem(
                value: '\$${todayEarnings.toStringAsFixed(0)}',
                label: l.t('today'),
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: Colors.white.withAlpha(179),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.white.withAlpha(51));
  }
}
