import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class AdminProvidersWidget extends StatefulWidget {
  const AdminProvidersWidget({super.key});

  @override
  State<AdminProvidersWidget> createState() => _AdminProvidersWidgetState();
}

class _AdminProvidersWidgetState extends State<AdminProvidersWidget> {
  String _filterStatus = 'All';

  List<String> get _filters {
    final l = LocalizationService.instance;
    return [l.t('all'), 'Pending', l.t('verified'), 'Suspended'];
  }

  final List<Map<String, dynamic>> _providers = [
    {
      'id': 1,
      'name': 'Marcus Johnson',
      'email': 'marcus.j@email.com',
      'phone': '+1 555-0101',
      'services': ['Towing', 'Jump Start'],
      'status': 'Pending',
      'rating': 0.0,
      'jobs': 0,
      'joined': 'May 1, 2026',
      'avatar': 'MJ',
    },
    {
      'id': 2,
      'name': 'Sarah Williams',
      'email': 'sarah.w@email.com',
      'phone': '+1 555-0102',
      'services': ['Flat Tire', 'Lockout'],
      'status': 'Verified',
      'rating': 4.8,
      'jobs': 142,
      'joined': 'Jan 15, 2026',
      'avatar': 'SW',
    },
    {
      'id': 3,
      'name': 'David Chen',
      'email': 'david.c@email.com',
      'phone': '+1 555-0103',
      'services': ['Fuel Delivery'],
      'status': 'Verified',
      'rating': 4.6,
      'jobs': 89,
      'joined': 'Feb 3, 2026',
      'avatar': 'DC',
    },
    {
      'id': 4,
      'name': 'Emma Rodriguez',
      'email': 'emma.r@email.com',
      'phone': '+1 555-0104',
      'services': ['Towing', 'Battery Replace'],
      'status': 'Suspended',
      'rating': 3.2,
      'jobs': 23,
      'joined': 'Mar 10, 2026',
      'avatar': 'ER',
    },
    {
      'id': 5,
      'name': 'James Park',
      'email': 'james.p@email.com',
      'phone': '+1 555-0105',
      'services': ['Jump Start', 'Flat Tire'],
      'status': 'Pending',
      'rating': 0.0,
      'jobs': 0,
      'joined': 'Apr 28, 2026',
      'avatar': 'JP',
    },
  ];

  List<Map<String, dynamic>> get _filteredProviders {
    final l = LocalizationService.instance;
    if (_filterStatus == l.t('all')) return _providers;
    // status mapping is a bit hardcoded here, but let's just use original status for internal filtering
    return _providers.where((p) {
      if (_filterStatus == 'Pending') return p['status'] == 'Pending';
      if (_filterStatus == l.t('verified')) return p['status'] == 'Verified';
      if (_filterStatus == 'Suspended') return p['status'] == 'Suspended';
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

  void _updateStatus(int id, String newStatus) {
    setState(() {
      final idx = _providers.indexWhere((p) => p['id'] == id);
      if (idx != -1) _providers[idx]['status'] = newStatus;
    });
  }

  void _showProviderDetail(Map<String, dynamic> provider) {
    final l = LocalizationService.instance;
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
                      provider['avatar'],
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
                          provider['name'],
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          provider['email'],
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
                      color: _statusBgColor(provider['status']),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(provider['status']),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(provider['status']),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.phone_outlined, l.t('phone'), provider['phone']),
              const SizedBox(height: 10),
              _detailRow(
                Icons.calendar_today_outlined,
                'Joined',
                provider['joined'],
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.star_outline,
                l.t('rating'),
                provider['rating'] == 0.0
                    ? 'No ratings yet'
                    : '${provider['rating']} / 5.0',
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.work_outline,
                'Completed Jobs',
                '${provider['jobs']}',
              ),
              const SizedBox(height: 16),
              Text(
                'Services Offered',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (provider['services'] as List<String>)
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                '${l.t('update_profile').split(' ')[0]} Status', // Hacky
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
                        _updateStatus(provider['id'], 'Verified');
                        Navigator.pop(ctx);
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
                        _updateStatus(provider['id'], 'Suspended');
                        Navigator.pop(ctx);
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
    if (_filterStatus == 'All') _filterStatus = l.t('all'); // Fix initial state

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
          '${_providers.where((p) => p['status'] == 'Pending').length} pending verification',
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = filtered[index];
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
                        p['avatar'],
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
                            p['name'],
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            (p['services'] as List<String>).join(' · '),
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
                            color: _statusBgColor(p['status']),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(p['status']),
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(p['status']),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p['jobs']} jobs',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.muted,
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
