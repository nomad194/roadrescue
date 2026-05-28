import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';
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

  /// Pick and upload vehicle size image
  Future<String?> _pickAndUploadVehicleSizeImage(Map<String, dynamic> category, String vehicleSizeId) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (picked == null) return null;

      final fileName = '${category['id']}_${vehicleSizeId}_${DateTime.now().millisecondsSinceEpoch}';
      final url = await SupabaseService.instance.uploadAppAsset(
        'app-assets',
        'vehicle_sizes/$fileName',
        picked.path,
      );
      return url;
    } catch (e) {
      debugPrint('Error uploading vehicle size image: $e');
      return null;
    }
  }

  void _showVehicleSizeDialog(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final List<String> selected = List<String>.from(
      category['vehicle_sizes'] ?? [],
    );
    // Load existing vehicle size images from category
    final Map<String, dynamic> existingImages = (category['vehicle_size_images'] as Map<String, dynamic>?) ?? {};
    final Map<String, String?> vehicleImages = {};
    for (final vehicle in _vehicleSizeOptions) {
      vehicleImages[vehicle['id'] as String] = existingImages[vehicle['id']] as String?;
    }

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
                  'Toggle vehicle sizes and upload custom images. Tap the image area to upload/change, X to remove.',
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
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _vehicleSizeOptions.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicleSizeOptions[index];
                    final vehicleId = vehicle['id'] as String;
                    final isEnabled = selected.contains(vehicleId);
                    final imageUrl = vehicleImages[vehicleId];

                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          if (isEnabled) {
                            selected.remove(vehicleId);
                          } else {
                            selected.add(vehicleId);
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
                            // Image or Emoji display
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                GestureDetector(
                                  onTap: isEnabled
                                      ? () async {
                                          final url = await _pickAndUploadVehicleSizeImage(category, vehicleId);
                                          if (url != null) {
                                            setDialogState(() {
                                              vehicleImages[vehicleId] = url;
                                            });
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isEnabled ? Colors.white.withAlpha(100) : AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isEnabled ? AppTheme.primary.withAlpha(100) : AppTheme.outline,
                                      ),
                                    ),
                                    child: imageUrl != null && imageUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Text(vehicle['emoji'] as String, style: const TextStyle(fontSize: 28)),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              vehicle['emoji'] as String,
                                              style: const TextStyle(fontSize: 28),
                                            ),
                                          ),
                                  ),
                                ),
                                // Remove image button (only show if image exists)
                                if (imageUrl != null && imageUrl.isNotEmpty && isEnabled)
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        vehicleImages[vehicleId] = null;
                                      });
                                    },
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppConstants.getVehicleSizeLabel(vehicle['id'] as String),
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
                            const SizedBox(height: 4),
                            // Upload button (only for enabled)
                            if (isEnabled)
                              TextButton.icon(
                                onPressed: () async {
                                  final url = await _pickAndUploadVehicleSizeImage(category, vehicleId);
                                  if (url != null) {
                                    setDialogState(() {
                                      vehicleImages[vehicleId] = url;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.upload, size: 14),
                                label: Text(
                                  imageUrl != null && imageUrl.isNotEmpty ? 'Change' : 'Upload',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                            else
                              const SizedBox(height: 28),
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
                  // Filter out null/empty values from images map
                  final Map<String, dynamic> imagesToSave = {};
                  vehicleImages.forEach((key, value) {
                    if (value != null && value.isNotEmpty) {
                      imagesToSave[key] = value;
                    }
                  });

                  await Supabase.instance.client
                      .from('service_categories')
                      .update({
                        'vehicle_sizes': selected,
                        'vehicle_size_images': imagesToSave,
                      })
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
          l.t('delete_category_confirmation'),
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

  void _showEditVehicleNamesDialog() async {
    final l = LocalizationService.instance;
    final langCodes = LocalizationService.supportedLanguages.keys.toList();

    // Load existing translations from app_settings
    final existing = await SupabaseService.instance.getAppSetting('vehicle_size_translations');
    Map<String, Map<String, String>> allTranslations = {};

    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = Map<String, dynamic>.from(json.decode(existing) as Map);
        for (final entry in decoded.entries) {
          allTranslations[entry.key] = Map<String, String>.from(
            (entry.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
      } catch (_) {}
    }

    // Pre-fill from language files if empty
    for (final vehicle in _vehicleSizeOptions) {
      final id = vehicle['id'] as String;
      if (!allTranslations.containsKey(id)) {
        allTranslations[id] = {};
      }
      for (final lang in langCodes) {
        if ((allTranslations[id]![lang] ?? '').isEmpty) {
          // Pull default from language file key
          final key = AppConstants.vehicleSizeLabelKeys[id];
          if (key != null && lang == l.currentLanguageCode) {
            final translated = l.t(key);
            if (translated != key) {
              allTranslations[id]![lang] = translated;
            }
          }
          // Also set English fallback from hardcoded label
          if (lang == 'en' && (allTranslations[id]!['en'] ?? '').isEmpty) {
            allTranslations[id]!['en'] = vehicle['label'] as String;
          }
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.translate, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('vehicle_name_translations'),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _vehicleSizeOptions.map((vehicle) {
                  final id = vehicle['id'] as String;
                  final emoji = vehicle['emoji'] as String;
                  final currentTranslations = allTranslations[id] ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            vehicle['label'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MultilingualTabsWidget(
                        initialTranslations: currentTranslations,
                        fieldLabel: vehicle['label'] as String,
                        hint: vehicle['label'] as String,
                        maxLines: 1,
                        onChanged: (updated) {
                          allTranslations[id] = updated;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
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
                try {
                  // Save to app_settings as JSON
                  final Map<String, dynamic> toSave = {};
                  for (final entry in allTranslations.entries) {
                    final nonEmpty = Map<String, String>.fromEntries(
                      entry.value.entries.where((e) => e.value.isNotEmpty),
                    );
                    if (nonEmpty.isNotEmpty) {
                      toSave[entry.key] = nonEmpty;
                    }
                  }

                  await SupabaseService.instance.updateAppSetting(
                    'vehicle_size_translations',
                    json.encode(toSave),
                  );

                  // Refresh the in-memory cache so labels update immediately
                  AppConstants.setVehicleSizeTranslations(json.encode(toSave));

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l.t('vehicle_names_saved'),
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
                } catch (e) {
                  debugPrint('Save vehicle names error: $e');
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
            OutlinedButton.icon(
              onPressed: _showEditVehicleNamesDialog,
              icon: const Icon(Icons.directions_car, size: 16),
              label: Text(
                l.t('edit_vehicle_names'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                                    '${vehicle['emoji']} ${AppConstants.getVehicleSizeLabel(vehicle['id'] as String)}',
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
