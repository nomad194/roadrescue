import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';

class AdminProvidersWidget extends StatefulWidget {
  const AdminProvidersWidget({super.key});

  @override
  State<AdminProvidersWidget> createState() => _AdminProvidersWidgetState();
}

class _AdminProvidersWidgetState extends State<AdminProvidersWidget> {
  String _filterStatus = 'All';
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('role', 'provider')
          .order('created_at', ascending: false);

      final providers = List<Map<String, dynamic>>.from(response);

      // Fetch completed job counts in batch
      for (final provider in providers) {
        try {
          final jobCount = await Supabase.instance.client
              .from('job_requests')
              .select('id')
              .eq('provider_id', provider['id'])
              .eq('job_status', 'completed');
          provider['_completed_jobs'] = (jobCount as List).length;
        } catch (_) {
          provider['_completed_jobs'] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _providers = providers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading providers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _filters {
    final l = LocalizationService.instance;
    return [l.t('all'), 'Pending', l.t('verified'), 'Suspended'];
  }

  String _getStatus(Map<String, dynamic> provider) {
    if (provider['is_suspended'] == true) return 'Suspended';
    if (provider['is_verified'] == true) return 'Verified';
    return 'Pending';
  }

  String _getInitials(Map<String, dynamic> provider) {
    final name = provider['full_name'] as String? ?? '';
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredProviders {
    final l = LocalizationService.instance;
    if (_filterStatus == l.t('all') || _filterStatus == 'All') return _providers;
    return _providers.where((p) {
      final status = _getStatus(p);
      if (_filterStatus == 'Pending') return status == 'Pending';
      if (_filterStatus == l.t('verified')) return status == 'Verified';
      if (_filterStatus == 'Suspended') return status == 'Suspended';
      return true;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Verified':
        return AppTheme.success;
      case 'Pending':
        return AppTheme.warning;
      case 'Suspended':
        return AppTheme.error;
      default:
        return AppTheme.muted;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Verified':
        return AppTheme.successContainer;
      case 'Pending':
        return AppTheme.warningContainer;
      case 'Suspended':
        return AppTheme.errorContainer;
      default:
        return AppTheme.surfaceVariant;
    }
  }

  String _statusLabel(String status) {
    final l = LocalizationService.instance;
    switch (status) {
      case 'Verified':
        return l.t('verified');
      case 'Pending':
        return 'Pending';
      case 'Suspended':
        return l.t('suspend');
      default:
        return status;
    }
  }

  Future<void> _updateStatus(String providerId, {bool? isVerified, bool? isSuspended}) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isVerified != null) data['is_verified'] = isVerified;
      if (isSuspended != null) data['is_suspended'] = isSuspended;

      await Supabase.instance.client
          .from('user_profiles')
          .update(data)
          .eq('id', providerId);

      await _loadProviders();
    } catch (e) {
      debugPrint('Error updating provider status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _deleteProvider(Map<String, dynamic> provider) async {
    final l = LocalizationService.instance;
    final providerId = provider['id'] as String;
    final providerEmail = provider['email'] as String? ?? 'Unknown';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l.t('delete_provider_confirmation'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        content: Text(
          l.t('delete_provider_with_email').replaceAll('{email}', providerEmail),
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('cancel'), style: GoogleFonts.manrope()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(
              l.t('delete'),
              style: GoogleFonts.manrope(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete from auth.users (cascades to user_profiles via FK)
      await SupabaseService.instance.client.auth.admin.deleteUser(providerId);

      // Remove from local list
      setState(() {
        _providers.removeWhere((p) => p['id'] == providerId);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('provider_deleted') ?? 'Provider deleted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting provider: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.t('error_deleting_provider') ?? 'Error deleting provider'}: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showProviderDetail(Map<String, dynamic> provider) {
    final l = LocalizationService.instance;
    final status = _getStatus(provider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryContainer,
                    child: Text(
                      _getInitials(provider),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider['full_name'] ?? '—',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          provider['email'] ?? '—',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBgColor(status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.phone_outlined, l.t('phone'), provider['phone'] ?? '—'),
              const SizedBox(height: 10),
              _detailRow(
                Icons.business_outlined,
                l.t('business_name'),
                provider['business_name'] ?? '—',
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.calendar_today_outlined,
                'Joined',
                _formatDate(provider['created_at'] as String?),
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.work_outline,
                'Completed Jobs',
                '${provider['_completed_jobs'] ?? 0}',
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.location_on_outlined,
                'Address',
                provider['address'] ?? '—',
              ),
              const SizedBox(height: 24),
              Text(
                'Update Status',
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
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(provider['id'], isVerified: true, isSuspended: false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        side: const BorderSide(color: AppTheme.success),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        l.t('verify'),
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(provider['id'], isVerified: false, isSuspended: true);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        l.t('suspend'),
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final filtered = _filteredProviders;
    if (_filterStatus == 'All') _filterStatus = l.t('all');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Provider Verification',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          '${_providers.where((p) => _getStatus(p) == 'Pending').length} pending verification',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSelected = _filterStatus == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterStatus = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No providers found',
                style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.muted),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = filtered[index];
              final status = _getStatus(p);
              return GestureDetector(
                onTap: () => _showProviderDetail(p),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryContainer,
                        child: Text(
                          _getInitials(p),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
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
                              p['full_name'] ?? '—',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              p['business_name'] ?? p['email'] ?? '',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBgColor(status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(status),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p['_completed_jobs'] ?? 0} jobs',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: AppTheme.muted,
                        ),
                        onSelected: (value) {
                          if (value == 'view') {
                            _showProviderDetail(p);
                          } else if (value == 'delete') {
                            _deleteProvider(p);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(l.t('view_details') ?? 'View Details', style: GoogleFonts.manrope()),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                const SizedBox(width: 8),
                                Text(l.t('delete_provider') ?? 'Delete Provider', style: GoogleFonts.manrope(color: AppTheme.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
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
