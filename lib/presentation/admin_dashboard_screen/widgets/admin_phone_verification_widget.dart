import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../services/localization_service.dart';
import '../../../theme/app_theme.dart';

/// Admin widget to manage phone verification status for users
/// Allows admins to manually verify/unverify users without SMS
class AdminPhoneVerificationWidget extends StatefulWidget {
  const AdminPhoneVerificationWidget({super.key});

  @override
  State<AdminPhoneVerificationWidget> createState() => _AdminPhoneVerificationWidgetState();
}

class _AdminPhoneVerificationWidgetState extends State<AdminPhoneVerificationWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Please enter an email to search';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
      _users = [];
    });

    try {
      final response = await SupabaseService.instance.client
          .from('user_profiles')
          .select('id, email, full_name, role, phone, phone_verified_at, is_verified')
          .ilike('email', '%$query%')
          .order('email', ascending: true)
          .limit(20);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      if (_users.isEmpty) {
        setState(() {
          _error = 'No users found with email containing "$query"';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePhoneVerification(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final isCurrentlyVerified = user['phone_verified_at'] != null;
    final l = LocalizationService.instance;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isCurrentlyVerified ? 'Unverify Phone?' : 'Verify Phone?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        content: Text(
          isCurrentlyVerified
              ? 'Remove phone verification for ${user['email']}?'
              : 'Mark phone as verified for ${user['email']}?',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('cancel'), style: GoogleFonts.manrope()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(
              l.t('confirm'),
              style: GoogleFonts.manrope(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      if (isCurrentlyVerified) {
        // Remove verification
        await SupabaseService.instance.client
            .from('user_profiles')
            .update({'phone_verified_at': null})
            .eq('id', userId);
      } else {
        // Set as verified
        await SupabaseService.instance.client
            .from('user_profiles')
            .update({'phone_verified_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
      }

      // Refresh the user list
      await _searchUsers();

      setState(() {
        _successMessage = isCurrentlyVerified
            ? 'Phone verification removed for ${user['email']}'
            : 'Phone verified for ${user['email']}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error updating phone verification: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAllUnverified() async {
    final l = LocalizationService.instance;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Verify All Unverified Users?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will mark all users without phone verification as verified. '
          'Use this when SMS service is disabled.',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('cancel'), style: GoogleFonts.manrope()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(
              l.t('confirm'),
              style: GoogleFonts.manrope(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await SupabaseService.instance.client
          .from('user_profiles')
          .update({'phone_verified_at': DateTime.now().toIso8601String()})
          .isFilter('phone_verified_at', null);

      setState(() {
        _successMessage = 'All unverified users have been marked as phone verified';
        _isLoading = false;
      });

      // Refresh if we have search results
      if (_searchController.text.isNotEmpty) {
        await _searchUsers();
      }
    } catch (e) {
      setState(() {
        _error = 'Error verifying users: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 200,
            maxHeight: MediaQuery.of(context).size.height - 200,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Verification Management',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        'Manually verify users when SMS service is disabled',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bulk verify button
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 140,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _verifyAllUnverified,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(
                          'Verify All',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by email...',
                      hintStyle: GoogleFonts.manrope(color: AppTheme.muted),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: GoogleFonts.manrope(),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchUsers,
                    icon: const Icon(Icons.search),
                    label: Text(
                      'Search',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error / Success messages
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.manrope(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: GoogleFonts.manrope(color: AppTheme.success),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),

            // Users list
            if (!_isLoading && _users.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isVerified = user['phone_verified_at'] != null;
                    final role = user['role'] as String? ?? 'customer';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: isVerified
                            ? AppTheme.success.withOpacity(0.2)
                            : AppTheme.warning.withOpacity(0.2),
                        child: Icon(
                          isVerified ? Icons.verified : Icons.phone_disabled,
                          color: isVerified ? AppTheme.success : AppTheme.warning,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        user['email'] ?? 'No email',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['full_name'] ?? 'Unknown'} • ${role.toUpperCase()}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          if (isVerified)
                            Text(
                              'Verified: ${user['phone_verified_at'].toString().substring(0, 10)}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.success,
                              ),
                            ),
                        ],
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _togglePhoneVerification(user),
                        icon: Icon(isVerified ? Icons.cancel : Icons.check_circle),
                        label: Text(
                          isVerified ? 'Unverify' : 'Verify',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVerified ? AppTheme.error : AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Empty state
            if (!_isLoading && _users.isEmpty && _searchController.text.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
