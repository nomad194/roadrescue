import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

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
        final id = cat['id'].toString();
        final isSelected = selectedId == id;

        return _CategoryTile(
          id: id,
          label: cat['label'] ?? '',
          iconEmoji: cat['icon'] ?? '🔧',
          iconImageUrl: cat['iconImageUrl'] as String?,
          isSelected: isSelected,
          onTap: () => onSelected(id),
          animationDelay: Duration(milliseconds: 30 * index),
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final String id;
  final String label;
  final String iconEmoji;
  final String? iconImageUrl;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _CategoryTile({
    required this.id,
    required this.label,
    required this.iconEmoji,
    this.iconImageUrl,
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
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final ts = ThemeService.instance;
        final boxBg = ts.serviceCategoryBoxBg.withAlpha((255 * ts.serviceCategoryBoxBgOpacity).round());
        final outlineColor = ts.serviceCategoryBoxOutline;
        final glowEnabled = ts.serviceCategoryBoxGlowEnabled;
        final glowStrength = ts.serviceCategoryBoxGlowStrength;

        final unselectedShadows = glowEnabled
            ? [
                BoxShadow(
                  color: outlineColor.withAlpha((90 * glowStrength).round().clamp(0, 255)),
                  blurRadius: 16 * glowStrength,
                  spreadRadius: 4 * glowStrength,
                ),
                BoxShadow(
                  color: outlineColor.withAlpha((50 * glowStrength).round().clamp(0, 255)),
                  blurRadius: 32 * glowStrength,
                  spreadRadius: 8 * glowStrength,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ];

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
                padding: widget.iconImageUrl != null && widget.iconImageUrl!.isNotEmpty
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isSelected ? AppTheme.primary : boxBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isSelected
                        ? AppTheme.primary
                        : outlineColor,
                    width: widget.isSelected ? 2 : 2,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(64),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : unselectedShadows,
                ),
                child: widget.iconImageUrl != null && widget.iconImageUrl!.isNotEmpty
                    ? _buildImageTile()
                    : Column(
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
                                alignment: Alignment.center,
                                child: Text(
                                  widget.iconEmoji,
                                  style: const TextStyle(fontSize: 20),
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
                          if (ts.showCategoryNames) ...[
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.iconImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                widget.iconEmoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          // Bottom gradient for text readability
          if (ThemeService.instance.showCategoryNames)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(0),
                      Colors.black.withAlpha(179),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Selection checkmark
          if (widget.isSelected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
