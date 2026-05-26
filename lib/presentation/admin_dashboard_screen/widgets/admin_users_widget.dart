import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class AdminUsersWidget extends StatefulWidget {
  const AdminUsersWidget({super.key});

  @override
  State<AdminUsersWidget> createState() => _AdminUsersWidgetState();
}

class _AdminUsersWidgetState extends State<AdminUsersWidget> {
  String _filterRole = 'All';
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _filters {
    final l = LocalizationService.instance;
    return [l.t('all'), l.t('customer'), l.t('provider'), l.t('admin')];
  }

  String _roleForFilter(String filter) {
    final l = LocalizationService.instance;
    if (filter == l.t('customer')) return 'customer';
    if (filter == l.t('provider')) return 'provider';
    if (filter == l.t('admin')) return 'admin';
    return 'all';
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final l = LocalizationService.instance;
    var list = _users;

    if (_filterRole != l.t('all') && _filterRole != 'All') {
      final role = _roleForFilter(_filterRole);
      list = list.where((u) => u['role'] == role).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        final name = (u['full_name'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final phone = (u['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    }

    return list;
  }

  String _getInitials(Map<String, dynamic> user) {
    final name = user['full_name'] as String? ?? '';
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppTheme.error;
      case 'provider':
        return AppTheme.primary;
      case 'customer':
        return AppTheme.success;
      default:
        return AppTheme.muted;
    }
  }

  Color _roleBgColor(String? role) {
    switch (role) {
      case 'admin':
        return AppTheme.errorContainer;
      case 'provider':
        return AppTheme.primaryContainer;
      case 'customer':
        return AppTheme.successContainer;
      default:
        return AppTheme.surfaceVariant;
    }
  }

  String _roleLabel(String? role) {
    final l = LocalizationService.instance;
    switch (role) {
      case 'admin':
        return l.t('admin');
      case 'provider':
        return l.t('provider');
      case 'customer':
        return l.t('customer');
      default:
        return role ?? '—';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _updateSuspended(String userId, bool suspended) async {
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'is_suspended': suspended,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      await _loadUsers();
    } catch (e) {
      debugPrint('Error updating user: $e');
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

  void _showUserDetail(Map<String, dynamic> user) {
    final l = LocalizationService.instance;
    final role = user['role'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
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
                    backgroundColor: _roleBgColor(role),
                    child: Text(
                      _getInitials(user),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _roleColor(role),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['full_name'] ?? '—',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          user['email'] ?? '—',
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
                      color: _roleBgColor(role),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _roleLabel(role),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _roleColor(role),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.phone_outlined, l.t('phone'), user['phone'] ?? '—'),
              const SizedBox(height: 10),
              _detailRow(
                Icons.calendar_today_outlined,
                'Joined',
                _formatDate(user['created_at'] as String?),
              ),
              const SizedBox(height: 10),
              _detailRow(
                Icons.location_on_outlined,
                'Address',
                user['address'] ?? '—',
              ),
              const SizedBox(height: 10),
              if (role == 'provider') ...[
                _detailRow(
                  Icons.business_outlined,
                  l.t('business_name'),
                  user['business_name'] ?? '—',
                ),
                const SizedBox(height: 10),
                _detailRow(
                  Icons.check_circle_outline,
                  l.t('verified'),
                  user['is_verified'] == true ? l.t('yes') : l.t('no'),
                ),
                const SizedBox(height: 10),
              ],
              _detailRow(
                Icons.toggle_on_outlined,
                l.t('status'),
                user['is_suspended'] == true ? 'Suspended' : 'Active',
              ),
              const SizedBox(height: 24),
              if (user['role'] != 'admin')
                Row(
                  children: [
                    if (user['is_suspended'] == true)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateSuspended(user['id'], false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.success,
                            side: const BorderSide(color: AppTheme.success),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Activate',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateSuspended(user['id'], true);
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
    final filtered = _filteredUsers;
    if (_filterRole == 'All') _filterRole = l.t('all');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCustomers = _users.where((u) => u['role'] == 'customer').length;
    final totalProviders = _users.where((u) => u['role'] == 'provider').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          '${_users.length} registered · $totalCustomers ${l.t('customer').toLowerCase()} · $totalProviders ${l.t('provider').toLowerCase()}',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: '${l.t('search')}...',
            hintStyle: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.muted),
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurface),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final isSelected = _filterRole == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterRole = f),
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
                'No users found',
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
              final u = filtered[index];
              final role = u['role'] as String? ?? '';
              return GestureDetector(
                onTap: () => _showUserDetail(u),
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
                        backgroundColor: _roleBgColor(role),
                        child: Text(
                          _getInitials(u),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _roleColor(role),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u['full_name'] ?? '—',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              u['email'] ?? '',
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
                              color: _roleBgColor(role),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _roleColor(role),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(u['created_at'] as String?),
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
