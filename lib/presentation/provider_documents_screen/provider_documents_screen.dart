import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import '../../routes/app_routes.dart';

class ProviderDocumentsScreen extends StatefulWidget {
  const ProviderDocumentsScreen({super.key});

  @override
  State<ProviderDocumentsScreen> createState() => _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  List<Map<String, dynamic>> _requiredTypes = [];
  List<Map<String, dynamic>> _providerDocs = [];
  bool _isLoading = true;
  bool _isUploading = false;
  int? _uploadingTypeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final types = await SupabaseService.instance.getRequiredDocumentTypes();
    final docs = await SupabaseService.instance.getProviderDocuments(userId);

    if (mounted) {
      setState(() {
        _requiredTypes = types;
        _providerDocs = docs;
        _isLoading = false;
      });
    }

    // Check if all verified → redirect
    _checkAllApproved();
  }

  void _checkAllApproved() {
    if (_requiredTypes.isEmpty) return;
    final approvedTypeIds = _providerDocs
        .where((d) => d['status'] == 'approved')
        .map((d) => d['document_type_id'] as int)
        .toSet();
    final allApproved = _requiredTypes.every((t) => approvedTypeIds.contains(t['id'] as int));

    if (allApproved && mounted) {
      // Show success then redirect
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.t('all_documents_approved'),
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.jobRequestsScreen, (r) => false);
        }
      });
    }
  }

  Map<String, dynamic>? _getDocForType(int typeId) {
    try {
      return _providerDocs.firstWhere((d) => d['document_type_id'] == typeId);
    } catch (_) {
      return null;
    }
  }

  int get _approvedCount => _providerDocs.where((d) => d['status'] == 'approved').length;

  Future<void> _uploadDocument(int typeId) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
            title: Text('Choose from Gallery',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
            title: Text('Take a Photo',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return;

    // Show preview dialog
    if (!mounted) return;
    final confirmed = await _showPreviewDialog(picked.path);
    if (confirmed != true) return;

    setState(() {
      _isUploading = true;
      _uploadingTypeId = typeId;
    });

    try {
      final result = await SupabaseService.instance.uploadProviderDocument(
        providerId: userId,
        documentTypeId: typeId,
        filePath: picked.path,
      );

      if (result != null) {
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload document. Please try again.',
                style: GoogleFonts.manrope(fontSize: 13),
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.manrope(fontSize: 13)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingTypeId = null;
        });
      }
    }
  }

  Future<bool?> _showPreviewDialog(String filePath) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          LocalizationService.instance.t('preview_document'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(filePath),
            width: double.maxFinite,
            height: 300,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: AppTheme.surfaceVariant,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.muted),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              LocalizationService.instance.t('cancel'),
              style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              LocalizationService.instance.t('confirm_upload'),
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'pending':
        return AppTheme.warning;
      default:
        return AppTheme.muted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_top;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          l.t('required_documents'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
            tooltip: l.t('sign_out'),
            onPressed: () async {
              await SupabaseService.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.signUpLoginScreen,
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requiredTypes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
                        const SizedBox(height: 16),
                        Text(
                          'No documents required',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can proceed to set up your services.',
                          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.jobRequestsScreen,
                              (r) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Continue', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress tracker
                      _buildProgressCard(l),
                      const SizedBox(height: 20),
                      // Document list
                      Text(
                        l.t('documents_required'),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.t('documents_required_desc'),
                        style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      ..._requiredTypes.map((type) => _buildDocumentCard(type)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProgressCard(LocalizationService l) {
    final total = _requiredTypes.length;
    final approved = _approvedCount;
    final progress = total > 0 ? approved / total : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withAlpha(20), AppTheme.primary.withAlpha(5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                approved == total ? Icons.verified : Icons.assignment_outlined,
                size: 24,
                color: approved == total ? AppTheme.success : AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  approved == total
                      ? l.t('all_documents_approved')
                      : l.t('documents_required'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                approved == total ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$approved / $total ${l.t('document_approved').toLowerCase()}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> type) {
    final l = LocalizationService.instance;
    final typeId = type['id'] as int;
    final existingDoc = _getDocForType(typeId);
    final status = existingDoc?['status'] as String?;
    final rejectionReason = existingDoc?['rejection_reason'] as String?;
    final isUploadingThis = _isUploading && _uploadingTypeId == typeId;

    final name = l.translateContent(
      type['name_translations'] as Map<String, dynamic>? ?? {},
      fallbackText: type['name'] as String? ?? '',
    );
    final instructions = l.translateContent(
      type['instructions_translations'] as Map<String, dynamic>? ?? {},
      fallbackText: type['instructions'] as String? ?? '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'approved'
              ? AppTheme.success.withAlpha(80)
              : status == 'rejected'
                  ? AppTheme.error.withAlpha(80)
                  : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status != null)
                Icon(_statusIcon(status), size: 20, color: _statusColor(status))
              else
                const Icon(Icons.upload_file, size: 20, color: AppTheme.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'approved'
                        ? l.t('document_approved')
                        : status == 'rejected'
                            ? l.t('document_rejected')
                            : l.t('document_pending'),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
            ],
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              instructions,
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ],
          // Rejection reason
          if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rejectionReason,
                      style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Upload / Re-upload button
          if (status != 'approved') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isUploadingThis
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _uploadDocument(typeId),
                      icon: Icon(
                        status == 'rejected' ? Icons.refresh : Icons.upload,
                        size: 16,
                      ),
                      label: Text(
                        status == 'rejected' ? l.t('reupload') : l.t('upload_document'),
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ),
          ],
          // Show uploaded image thumbnail
          if (existingDoc != null && (existingDoc['file_url'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                existingDoc['file_url'] as String,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
