import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminCategoriesWidget extends StatefulWidget {
  const AdminCategoriesWidget({super.key});

  @override
  State<AdminCategoriesWidget> createState() => _AdminCategoriesWidgetState();
}

class _AdminCategoriesWidgetState extends State<AdminCategoriesWidget> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('service_categories')
          .select()
          .order('id', ascending: true);
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Use shared vehicle size options from AppConstants
  List<Map<String, dynamic>> get _vehicleSizeOptions => AppConstants.vehicleSizeOptions;

  String _getCategoryName(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final translations =
        category['name_translations'] as Map<String, dynamic>? ?? {};
    return l.translateContent(
      translations,
      fallbackText: category['name'] as String? ?? '',
    );
  }

  void _showVehicleSizeDialog(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final List<String> selected = List<String>.from(
      category['vehicle_sizes'] ?? [],
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
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('service_categories')
                      .update({'vehicle_sizes': selected})
                      .eq('id', category['id']);

                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    nav.pop();
                    messenger.showSnackBar(
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
                  }
                  await _loadCategories();
                } catch (e) {
                  debugPrint('Update vehicle sizes error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update: $e'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
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
    Map<String, String> nameTranslations = {};

    if (category != null) {
      final nameMap = category['name_translations'] as Map?;
      if (nameMap != null) {
        nameTranslations = nameMap.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      } else if ((category['name'] as String?)?.isNotEmpty == true) {
        nameTranslations = {'en': category['name'] as String};
      }
    }

    final iconController = TextEditingController(
      text: category?['icon_emoji'] ?? '',
    );
    bool isActive = category?['is_active'] ?? true;

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
              onPressed: () async {
                final hasName = nameTranslations.values.any(
                  (v) => v.isNotEmpty,
                );
                if (!hasName) return;

                final primaryName =
                    nameTranslations['en'] ?? nameTranslations.values.first;
                final categoryData = {
                  'name': primaryName,
                  'name_translations': nameTranslations,
                  'icon_emoji': iconController.text.trim().isEmpty
                      ? (category?['icon_emoji'] ?? '🔧')
                      : iconController.text.trim(),
                  'is_active': isActive,
                };

                try {
                  if (category == null) {
                    await Supabase.instance.client
                        .from('service_categories')
                        .insert(categoryData);
                  } else {
                    await Supabase.instance.client
                        .from('service_categories')
                        .update(categoryData)
                        .eq('id', category['id']);
                  }
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Category saved!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  await _loadCategories();
                } catch (e) {
                  debugPrint('Save category error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
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
          '${l.t('delete')} ${l.t('categories').substring(0, l.t('categories').length - 1)}', // Hacky singular
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
            onPressed: () async {
              debugPrint('Deleting category ID: $id');
              try {
                debugPrint('Attempting delete...');
                await Supabase.instance.client
                    .from('service_categories')
                    .delete()
                    .eq('id', id);
                debugPrint('Delete successful');
                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                await _loadCategories();
              } catch (e) {
                debugPrint('Delete category error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
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
                l.t('add_translation').contains(' ')
                    ? '${l.t('add_translation').split(' ')[0]} ${l.t('categories').substring(0, l.t('categories').length - 1)}'
                    : l.t('add_plan'),
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
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_categories.isEmpty)
          const Center(child: Text('No categories found.'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final vehicleSizes =
                  (cat['vehicle_sizes'] as List<dynamic>?) ?? [];
              final displayName = _getCategoryName(cat);
              final isActive = cat['is_active'] ?? true;
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
                            color: isActive
                                ? AppTheme.primaryContainer
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              cat['icon_emoji'] ?? '🔧',
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
                                    '${cat['providers_count'] ?? 0} providers',
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
                                    '${(cat['name_translations'] as Map?)?.length ?? 0} langs',
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
                            color: isActive
                                ? AppTheme.successContainer
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? l.t('active') : 'Inactive',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppTheme.success
                                  : AppTheme.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => _showVehicleSizeDialog(cat),
                          icon: const Text(
                            '🚗',
                            style: TextStyle(fontSize: 16),
                          ),
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
                                  orElse: () => {
                                    'emoji': '🚗',
                                    'label': sizeId,
                                  },
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
