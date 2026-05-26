import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class JobFilterBarWidget extends StatelessWidget {
  final String selectedFilter;
  final String selectedStatusFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const JobFilterBarWidget({
    super.key,
    required this.selectedFilter,
    required this.selectedStatusFilter,
    required this.onFilterChanged,
    required this.onStatusFilterChanged,
  });

  List<Map<String, String>> get _serviceFilters {
    final l = LocalizationService.instance;
    return [
      {'id': 'all', 'label': l.t('all')},
      {'id': 'towing', 'label': l.t('service_towing')},
      {'id': 'flat_tire', 'label': l.t('service_flat_tire')},
      {'id': 'lockout', 'label': l.t('service_lockout')},
      {'id': 'fuel_delivery', 'label': l.t('service_fuel')},
      {'id': 'jump_start', 'label': l.t('service_jump_start')},
      {'id': 'battery', 'label': l.t('service_battery')},
    ];
  }

  List<Map<String, String>> get _statusFilters {
    final l = LocalizationService.instance;
    return [
      {'id': 'all', 'label': l.t('all')},
      {'id': 'new', 'label': l.t('tab_new')},
      {'id': 'quoted', 'label': l.t('tab_quoted')},
      {'id': 'accepted', 'label': l.t('status_accepted')},
      {'id': 'completed', 'label': l.t('status_done')},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _serviceFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _serviceFilters[index];
                final isSelected = selectedFilter == filter['id'];
                return _FilterChip(
                  label: filter['label']!,
                  isSelected: isSelected,
                  onTap: () => onFilterChanged(filter['id']!),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = selectedStatusFilter == filter['id'];
                return _StatusFilterChip(
                  label: filter['label']!,
                  isSelected: isSelected,
                  onTap: () => onStatusFilterChanged(filter['id']!),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppTheme.outlineVariant),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.muted,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
