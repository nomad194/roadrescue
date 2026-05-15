import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminCategoriesWidget extends StatefulWidget {
  const AdminCategoriesWidget({super.key});

  @override
  State<AdminCategoriesWidget> createState() => _AdminCategoriesWidgetState();
}

class _AdminCategoriesWidgetState extends State<AdminCategoriesWidget> {
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 1,
      'translations': <String, String>{
        'en': 'Towing',
        'es': 'Remolque',
        'fr': 'Remorquage',
        'pt': 'Reboque',
        'de': 'Abschleppen',
        'ar': 'سحب السيارة',
      },
      'icon': '🚗',
      'active': true,
      'providers': 24,
      'vehicleSizes': [
        'motorcycle',
        'sedan',
        'suv',
        'pickup',
        'van',
        'large_truck',
      ],
    },
    {
      'id': 2,
      'translations': <String, String>{
        'en': 'Flat Tire',
        'es': 'Llanta Ponchada',
        'fr': 'Pneu Crevé',
        'pt': 'Pneu Furado',
        'de': 'Reifenpanne',
        'ar': 'إطار مثقوب',
      },
      'icon': '🔧',
      'active': true,
      'providers': 18,
      'vehicleSizes': ['motorcycle', 'sedan', 'suv', 'pickup'],
    },
    {
      'id': 3,
      'translations': <String, String>{
        'en': 'Lockout',
        'es': 'Apertura de Vehículo',
        'fr': 'Ouverture de Véhicule',
        'pt': 'Abertura de Veículo',
        'de': 'Fahrzeugöffnung',
        'ar': 'فتح السيارة',
      },
      'icon': '🔑',
      'active': true,
      'providers': 15,
      'vehicleSizes': ['sedan', 'suv', 'pickup', 'van'],
    },
    {
      'id': 4,
      'translations': <String, String>{
        'en': 'Fuel Delivery',
        'es': 'Entrega de Combustible',
        'fr': 'Livraison de Carburant',
        'pt': 'Entrega de Combustível',
        'de': 'Kraftstofflieferung',
        'ar': 'توصيل الوقود',
      },
      'icon': '⛽',
      'active': true,
      'providers': 12,
      'vehicleSizes': ['motorcycle', 'sedan', 'suv', 'pickup', 'van'],
    },
    {
      'id': 5,
      'translations': <String, String>{
        'en': 'Jump Start',
        'es': 'Arranque de Batería',
        'fr': 'Démarrage de Batterie',
        'pt': 'Partida de Bateria',
        'de': 'Starthilfe',
        'ar': 'تشغيل البطارية',
      },
      'icon': '⚡',
      'active': false,
      'providers': 9,
      'vehicleSizes': ['sedan', 'suv'],
    },
    {
      'id': 6,
      'translations': <String, String>{
        'en': 'Battery Replace',
        'es': 'Cambio de Batería',
        'fr': 'Remplacement de Batterie',
        'pt': 'Troca de Bateria',
        'de': 'Batteriewechsel',
        'ar': 'استبدال البطارية',
      },
      'icon': '🔋',
      'active': true,
      'providers': 7,
      'vehicleSizes': ['sedan', 'suv', 'pickup'],
    },
  ];

  static const List<Map<String, dynamic>> _vehicleSizeOptions = [
    {
      'id': 'motorcycle',
      'label': 'Motorcycle',
      'emoji': '🏍️',
      'imageUrl':
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=120&h=80&fit=crop',
    },
    {
      'id': 'sedan',
      'label': 'Sedan / Car',
      'emoji': '🚗',
      'imageUrl':
          'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=120&h=80&fit=crop',
    },
    {
      'id': 'suv',
      'label': 'SUV / Crossover',
      'emoji': '🚙',
      'imageUrl':
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=120&h=80&fit=crop',
    },
    {
      'id': 'pickup',
      'label': 'Pickup Truck',
      'emoji': '🛻',
      'imageUrl':
          'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=120&h=80&fit=crop',
    },
    {
      'id': 'van',
      'label': 'Van / Minivan',
      'emoji': '🚐',
      'imageUrl':
          'https://images.unsplash.com/photo-1609521263047-f8f205293f24?w=120&h=80&fit=crop',
    },
    {
      'id': 'large_truck',
      'label': 'Large Truck',
      'emoji': '🚛',
      'imageUrl':
          'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=120&h=80&fit=crop',
    },
  ];

  String _getCategoryName(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final translations = category['translations'] as Map<String, dynamic>? ?? {};
    return l.translateContent(
      translations,
      fallbackText: category['name'] as String? ?? '',
    );
  }

  void _showVehicleSizeDialog(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final List<String> selected = List<String>.from(
      category['vehicleSizes'] ?? [],
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('vehicle_size'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                'for ${_getCategoryName(category)}',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toggle which vehicle sizes are available for this service. These will appear as options in the customer app.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _vehicleSizeOptions.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicleSizeOptions[index];
                    final isEnabled = selected.contains(vehicle['id']);
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          if (isEnabled) {
                            selected.remove(vehicle['id']);
                          } else {
                            selected.add(vehicle['id'] as String);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppTheme.primaryContainer
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEnabled
                                ? AppTheme.primary
                                : AppTheme.outline,
                            width: isEnabled ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vehicle['emoji'] as String,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle['label'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isEnabled
                                    ? AppTheme.primary
                                    : AppTheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isEnabled) ...[
                              const SizedBox(height: 2),
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final idx = _categories.indexWhere(
                    (c) => c['id'] == category['id'],
                  );
                  if (idx != -1) {
                    _categories[idx]['vehicleSizes'] = List<String>.from(
                      selected,
                    );
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Vehicle sizes updated for ${_getCategoryName(category)}',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? category}) {
    final l = LocalizationService.instance;
    Map<String, String> nameTranslations = category != null
        ? Map<String, String>.from(
            category['translations'] as Map<String, String>? ?? {},
          )
        : {};
    final iconController = TextEditingController(text: category?['icon'] ?? '');
    bool isActive = category?['active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.translate, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                category == null ? 'Add Category' : 'Edit Category',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multilingual name tabs
                  Text(
                    'Category Name',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: nameTranslations,
                    fieldLabel: 'Category Name',
                    hint: 'e.g. Towing',
                    maxLines: 1,
                    onChanged: (updated) => nameTranslations = updated,
                  ),
                  const SizedBox(height: 12),
                  // Icon
                  Text(
                    'Icon (emoji)',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: iconController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 🚗',
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        l.t('active'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final hasName = nameTranslations.values.any(
                  (v) => v.isNotEmpty,
                );
                if (!hasName) return;
                setState(() {
                  if (category == null) {
                    _categories.add({
                      'id': _categories.length + 1,
                      'translations': nameTranslations,
                      'icon': iconController.text.trim().isEmpty
                          ? '🔧'
                          : iconController.text.trim(),
                      'active': isActive,
                      'providers': 0,
                      'vehicleSizes': ['sedan', 'suv'],
                    });
                  } else {
                    final idx = _categories.indexWhere(
                      (c) => c['id'] == category['id'],
                    );
                    if (idx != -1) {
                      _categories[idx] = {
                        ...category,
                        'translations': nameTranslations,
                        'icon': iconController.text.trim().isEmpty
                            ? category['icon']
                            : iconController.text.trim(),
                        'active': isActive,
                      };
                    }
                  }
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(int id) {
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${l.t('delete')} ${l.t('categories').substring(0, l.t('categories').length-1)}', // Hacky singular
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this category?',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.t('cancel'),
              style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _categories.removeWhere((c) => c['id'] == id));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l.t('delete'),
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service ${l.t('categories')}',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_categories.length} ${l.t('categories').toLowerCase()} defined',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                l.t('add_translation').split(' ')[0],
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(90, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final vehicleSizes = (cat['vehicleSizes'] as List<dynamic>?) ?? [];
            final displayName = _getCategoryName(cat);
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cat['active']
                              ? AppTheme.primaryContainer
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            cat['icon'],
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${cat['providers']} providers',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.translate,
                                  size: 10,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${(cat['translations'] as Map?)?.length ?? 0} langs',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cat['active']
                              ? AppTheme.successContainer
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat['active'] ? l.t('active') : 'Inactive',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cat['active']
                                ? AppTheme.success
                                : AppTheme.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _showVehicleSizeDialog(cat),
                        icon: const Text('🚗', style: TextStyle(fontSize: 16)),
                        tooltip: l.t('vehicle_size'),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.secondaryContainer,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _showAddEditDialog(category: cat),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _deleteCategory(cat['id']),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppTheme.error,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.errorContainer,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  if (vehicleSizes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppTheme.outlineVariant),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${l.t('vehicle_size')}:',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: vehicleSizes.map((sizeId) {
                              final vehicle = _vehicleSizeOptions.firstWhere(
                                (v) => v['id'] == sizeId,
                                orElse: () => {'emoji': '🚗', 'label': sizeId},
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${vehicle['emoji']} ${vehicle['label']}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
