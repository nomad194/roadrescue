import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';

class RequestFormWidget extends StatelessWidget {
  final TextEditingController controller;
  final String urgencyLevel;
  final ValueChanged<String> onUrgencyChanged;

  const RequestFormWidget({
    super.key,
    required this.controller,
    required this.urgencyLevel,
    required this.onUrgencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('additional_details'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: l.t('describe_situation_hint'),
              hintStyle: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.muted,
              ),
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: GoogleFonts.manrope(
                fontSize: 11,
                color: AppTheme.muted,
              ),
            ),
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('urgency_level'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _UrgencyChip(
                label: l.t('standard_urgency'),
                sublabel: l.t('no_immediate_danger'),
                icon: Icons.access_time_rounded,
                color: AppTheme.primary,
                isSelected: urgencyLevel == 'standard',
                onTap: () => onUrgencyChanged('standard'),
              ),
              const SizedBox(width: 8),
              _UrgencyChip(
                label: l.t('urgent_urgency'),
                sublabel: l.t('safety_concern'),
                icon: Icons.priority_high_rounded,
                color: AppTheme.error,
                isSelected: urgencyLevel == 'urgent',
                onTap: () => onUrgencyChanged('urgent'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.t('urgent_request_info'),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.muted,
                      height: 1.4,
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

class _UrgencyChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UrgencyChip({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(26) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppTheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? color : AppTheme.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? color : AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
