import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminDocumentTypesWidget extends StatefulWidget {
  const AdminDocumentTypesWidget({super.key});

  @override
  State<AdminDocumentTypesWidget> createState() => _AdminDocumentTypesWidgetState();
}

class _AdminDocumentTypesWidgetState extends State<AdminDocumentTypesWidget> {
  List<Map<String, dynamic>> _docTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocTypes();
  }

  Future<void> _loadDocTypes() async {
    setState(() => _isLoading = true);
    final types = await SupabaseService.instance.getAllDocumentTypes();
    if (mounted) {
      setState(() {
        _docTypes = types;
        _isLoading = false;
      });
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    final l = LocalizationService.instance;
    final isEditing = existing != null;

    Map<String, String> nameTranslations = {};
    Map<String, String> instructionsTranslations = {};

    if (isEditing) {
      final nameT = existing['name_translations'] as Map<String, dynamic>? ?? {};
      nameTranslations = nameT.map((k, v) => MapEntry(k, v.toString()));
      if (nameTranslations['en']?.isEmpty ?? true) {
        nameTranslations['en'] = existing['name'] as String? ?? '';
      }

      final instrT = existing['instructions_translations'] as Map<String, dynamic>? ?? {};
      instructionsTranslations = instrT.map((k, v) => MapEntry(k, v.toString()));
      if (instructionsTranslations['en']?.isEmpty ?? true) {
        instructionsTranslations['en'] = existing['instructions'] as String? ?? '';
      }
    }

    final sortController = TextEditingController(
      text: isEditing ? (existing['sort_order']?.toString() ?? '0') : '0',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_document : Icons.add_circle_outline,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEditing ? l.t('edit') : l.t('add_translation'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('required_documents'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: nameTranslations,
                    fieldLabel: 'Name',
                    hint: 'e.g. Driver\'s License',
                    maxLines: 1,
                    onChanged: (updated) {
                      nameTranslations = updated;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.t('document_instructions'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: instructionsTranslations,
                    fieldLabel: 'Instructions',
                    hint: 'e.g. Upload a clear photo of your license',
                    maxLines: 3,
                    onChanged: (updated) {
                      instructionsTranslations = updated;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sort Order',
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                    ),
                    style: GoogleFonts.manrope(fontSize: 13),
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
                final name = nameTranslations['en'] ?? nameTranslations.values.firstWhere((v) => v.isNotEmpty, orElse: () => '');
                if (name.isEmpty) return;

                final data = {
                  'name': name,
                  'name_translations': nameTranslations,
                  'instructions': instructionsTranslations['en'] ?? '',
                  'instructions_translations': instructionsTranslations,
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                };

                bool success;
                if (isEditing) {
                  success = await SupabaseService.instance.updateDocumentType(existing['id'] as int, data);
                } else {
                  final result = await SupabaseService.instance.createDocumentType(data);
                  success = result != null;
                }

                if (success && mounted) {
                  Navigator.pop(ctx);
                  _loadDocTypes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing ? 'Document type updated' : 'Document type created',
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _confirmDeactivate(Map<String, dynamic> docType) {
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l.t('confirm'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Deactivate "${docType['name']}"? Providers will no longer need to upload this document.',
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('cancel'), style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await SupabaseService.instance.deactivateDocumentType(docType['id'] as int);
              if (success) _loadDocTypes();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l.t('delete'), style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                    l.t('required_documents'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_docTypes.where((d) => d['is_active'] == true).length} active document types',
                    style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                l.t('add_translation'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_docTypes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.description_outlined, size: 48, color: AppTheme.muted),
                  const SizedBox(height: 12),
                  Text(
                    'No document types defined yet',
                    style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add required documents that providers must upload',
                    style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _docTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = _docTypes[index];
              final isActive = doc['is_active'] == true;
              final name = LocalizationService.instance.translateContent(
                doc['name_translations'] as Map<String, dynamic>? ?? {},
                fallbackText: doc['name'] as String? ?? '',
              );
              final instructions = LocalizationService.instance.translateContent(
                doc['instructions_translations'] as Map<String, dynamic>? ?? {},
                fallbackText: doc['instructions'] as String? ?? '',
              );

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.surface : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppTheme.outlineVariant : AppTheme.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${doc['sort_order'] ?? index + 1}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppTheme.primary : AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? AppTheme.onSurface : AppTheme.muted,
                                    decoration: isActive ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              if (!isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Inactive',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (instructions.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              instructions,
                              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.muted),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(l.t('edit'), style: GoogleFonts.manrope(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (isActive)
                          PopupMenuItem(
                            value: 'deactivate',
                            child: Row(
                              children: [
                                const Icon(Icons.block, size: 16, color: AppTheme.error),
                                const SizedBox(width: 8),
                                Text('Deactivate', style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.error)),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showAddEditDialog(existing: doc);
                        } else if (action == 'deactivate') {
                          _confirmDeactivate(doc);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
