import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';

class AdminDocumentReviewWidget extends StatefulWidget {
  const AdminDocumentReviewWidget({super.key});

  @override
  State<AdminDocumentReviewWidget> createState() => _AdminDocumentReviewWidgetState();
}

class _AdminDocumentReviewWidgetState extends State<AdminDocumentReviewWidget> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String _statusFilter = 'all';

  final List<String> _filters = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final filter = _statusFilter == 'all' ? null : _statusFilter;
    final docs = await SupabaseService.instance.getAllProviderDocuments(statusFilter: filter);
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
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

  Color _statusBgColor(String status) {
    switch (status) {
      case 'approved':
        return AppTheme.successContainer;
      case 'rejected':
        return AppTheme.errorContainer;
      case 'pending':
        return AppTheme.warningContainer;
      default:
        return AppTheme.surfaceVariant;
    }
  }

  void _showDocumentDetail(Map<String, dynamic> doc) {
    final l = LocalizationService.instance;
    final provider = doc['user_profiles'] as Map<String, dynamic>? ?? {};
    final docType = doc['required_document_types'] as Map<String, dynamic>? ?? {};
    final status = doc['status'] as String? ?? 'pending';
    final fileUrl = doc['file_url'] as String? ?? '';
    final rejectionReason = doc['rejection_reason'] as String?;
    final reviewedAt = doc['reviewed_at'] as String?;
    final documentId = doc['id'] as String;

    final docTypeName = LocalizationService.instance.translateContent(
      docType['name_translations'] as Map<String, dynamic>? ?? {},
      fallbackText: docType['name'] as String? ?? 'Document',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Provider info
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryContainer,
                    child: Text(
                      _getInitials(provider['full_name'] as String? ?? ''),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider['full_name'] as String? ?? 'Unknown',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          provider['email'] as String? ?? '',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBgColor(status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Document type
              Text(
                docTypeName,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Document image
              if (fileUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => _showFullScreenImage(fileUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fileUrl,
                      width: double.infinity,
                      height: 280,
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
                ),
              const SizedBox(height: 12),
              Text(
                'Tap image to view full screen',
                style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              // Rejection reason if rejected
              if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rejectionReason,
                          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Audit info
              if (reviewedAt != null) ...[
                Text(
                  'Reviewed: ${_formatDate(reviewedAt)}',
                  style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
              ],
              // Action buttons (only if pending)
              if (status == 'pending') ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Review Actions',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _approveDocument(documentId);
                        },
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: Text(l.t('document_approved'), style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRejectDialog(documentId);
                        },
                        icon: const Icon(Icons.cancel, size: 16, color: AppTheme.error),
                        label: Text(
                          l.t('document_rejected'),
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppTheme.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveDocument(String documentId) async {
    final reviewerId = Supabase.instance.client.auth.currentUser?.id;
    if (reviewerId == null) return;
    final success = await SupabaseService.instance.approveProviderDocument(documentId, reviewerId);
    if (success) _loadDocuments();
  }

  void _showRejectDialog(String documentId) {
    final l = LocalizationService.instance;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l.t('rejection_reason'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter reason for rejection...',
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
          ),
          style: GoogleFonts.manrope(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('cancel'), style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final reviewerId = Supabase.instance.client.auth.currentUser?.id;
              if (reviewerId == null) return;
              final success = await SupabaseService.instance.rejectProviderDocument(documentId, reviewerId, reason);
              if (success) _loadDocuments();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reject', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('document_review'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          '${_documents.where((d) => d['status'] == 'pending').length} pending review',
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSelected = _statusFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _statusFilter = f);
                    _loadDocuments();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f == 'all' ? l.t('all') : f[0].toUpperCase() + f.substring(1),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_documents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No documents found',
                style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.muted),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = _documents[index];
              final provider = doc['user_profiles'] as Map<String, dynamic>? ?? {};
              final docType = doc['required_document_types'] as Map<String, dynamic>? ?? {};
              final status = doc['status'] as String? ?? 'pending';

              final docTypeName = LocalizationService.instance.translateContent(
                docType['name_translations'] as Map<String, dynamic>? ?? {},
                fallbackText: docType['name'] as String? ?? 'Document',
              );

              return GestureDetector(
                onTap: () => _showDocumentDetail(doc),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          doc['file_url'] as String? ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.surfaceVariant,
                            child: const Icon(Icons.description, size: 20, color: AppTheme.muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider['full_name'] as String? ?? 'Unknown',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              docTypeName,
                              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusBgColor(status),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
