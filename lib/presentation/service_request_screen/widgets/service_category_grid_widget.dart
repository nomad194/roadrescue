import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class ServiceCategoryGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final int crossAxisCount;

  const ServiceCategoryGridWidget({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.crossAxisCount = 2,
  });

  IconData _iconFromString(String name) {
    switch (name) {
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'tire_repair':
        return Icons.tire_repair_rounded;
      case 'lock_open':
        return Icons.lock_open_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'battery_alert':
        return Icons.battery_alert_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  String _getLabel(Map<String, dynamic> cat) {
    final l = LocalizationService.instance;
    final translations = cat['translations'] as Map?;
    if (translations != null) {
      return l.translateContent(
        translations.map((k, v) => MapEntry(k.toString(), v.toString())),
        fallbackText: cat['label'] as String? ?? '',
      );
    }
    return cat['label'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = selectedId == cat['id'];
        return _CategoryTile(
          id: cat['id'] as String,
          label: _getLabel(cat),
          icon: _iconFromString(cat['icon'] as String),
          description: cat['description'] as String,
          avgTime: cat['avgTime'] as String,
          isSelected: isSelected,
          onTap: () => onSelected(cat['id'] as String),
          animationDelay: Duration(milliseconds: 60 * index),
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final String id;
  final String label;
  final IconData icon;
  final String description;
  final String avgTime;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _CategoryTile({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.avgTime,
    required this.isSelected,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.animationDelay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.96),
        onTapUp: (_) {
          setState(() => _scale = 1.0);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isSelected ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.primary
                    : AppTheme.outlineVariant,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(64),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? Colors.white.withAlpha(51)
                            : AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: widget.isSelected
                            ? Colors.white
                            : AppTheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isSelected
                        ? Colors.white
                        : AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.avgTime,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: widget.isSelected
                        ? Colors.white.withAlpha(204)
                        : AppTheme.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
