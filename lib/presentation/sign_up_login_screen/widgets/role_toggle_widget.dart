import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class RoleToggleWidget extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const RoleToggleWidget({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('i_am_a'),
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _RoleTab(
                label: l.t('driver'),
                icon: Icons.directions_car_rounded,
                isSelected: selectedRole == 'customer',
                onTap: () => onRoleChanged('customer'),
              ),
              _RoleTab(
                label: l.t('provider'),
                icon: Icons.build_circle_rounded,
                isSelected: selectedRole == 'provider',
                onTap: () => onRoleChanged('provider'),
              ),
              _RoleTab(
                label: l.t('admin'),
                icon: Icons.admin_panel_settings_outlined,
                isSelected: selectedRole == 'admin',
                onTap: () => onRoleChanged('admin'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.icon,
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
