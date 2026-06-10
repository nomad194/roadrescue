import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import '../../routes/app_routes.dart';
import 'package:roadrescue_shared/widgets/language_selector_widget.dart';
import 'widgets/customer_language_dialog.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/widgets/themed_alert_dialog.dart';

class CustomerProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMyVehicle;
  final VoidCallback? onNavigateToServiceHistory;
  final VoidCallback? onNavigateToFAQ;
  final VoidCallback? onNavigateToSupport;

  const CustomerProfileScreen({
    super.key,
    this.onNavigateToMyVehicle,
    this.onNavigateToServiceHistory,
    this.onNavigateToFAQ,
    this.onNavigateToSupport,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isDeletingAccount = false;
  bool _notificationsEnabled = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _avatarUrl;
  int _totalRequests = 0;
  int _completedRequests = 0;
  String _originalPhone = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;
      final response = await SupabaseService.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'notifications_enabled_$userId')
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _notificationsEnabled = response['setting_value'] == 'true';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveNotificationPreference(bool enabled) async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.instance.client
          .from('app_settings')
          .upsert({
            'setting_key': 'notifications_enabled_$userId',
            'setting_value': enabled.toString(),
          });
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (_) {}
  }

  void _showNotificationSettings() {
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => ThemedAlertDialog(role: 'customer',
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withAlpha(80)),
          ),
          title: Text(
            l.t('notifications'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.t('enable_notifications'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    activeColor: AppTheme.serviceRequestAccent,
                    onChanged: (value) {
                      setDialogState(() => _notificationsEnabled = value);
                      _saveNotificationPreference(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.t('receive_notifications_for'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l.t('notif_quote_acceptances')}\n${l.t('notif_payment_confirmations')}\n${l.t('notif_job_status_updates')}',
                style: GoogleFonts.manrope(fontSize: 13, color: Colors.white.withAlpha(180)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('close'), style: TextStyle(color: AppTheme.serviceRequestAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.instance.getUserProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile['full_name'] as String? ?? '';
          _emailController.text = profile['email'] as String? ??
              SupabaseService.instance.currentUser?.email ?? '';
          _phoneController.text = profile['phone'] as String? ?? '';
          _originalPhone = profile['phone'] as String? ?? '';
          _addressController.text = profile['address'] as String? ?? '';
          _avatarUrl = profile['avatar_url'] as String?;
        });
      }

      // Load job counts
      final jobs = await SupabaseService.instance.getJobHistory();
      if (mounted) {
        setState(() {
          _totalRequests = jobs.length;
          _completedRequests = jobs.where((j) => j['job_status'] == 'completed').length;
        });
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    final l = LocalizationService.instance;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: Text(l.t('choose_from_gallery'),
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: Text(l.t('take_photo'),
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await SupabaseService.instance.uploadAvatar(userId, picked.path);
      await SupabaseService.instance.updateProfile(userId, {'avatar_url': url});
      if (mounted) {
        setState(() => _avatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo updated!',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload photo: $e',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
  }

  Future<void> _saveProfile() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    final l = LocalizationService.instance;
    final newPhone = _phoneController.text.trim();

    // If phone changed, require re-verification
    if (newPhone != _originalPhone && newPhone.isNotEmpty) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t('phone_change_verify'),
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pushNamed(
        context,
        AppRoutes.phoneVerificationScreen,
        arguments: {'phone': newPhone, 'updateProfile': true},
      ).then((_) {
        _phoneController.text = _originalPhone;
        _loadProfile();
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.updateProfile(userId, {
        'address': _addressController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t('profile_updated'),
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving profile: $e',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final ts = ThemeService.instance;
    final screenBg = ts.userScreenBgColor.withAlpha((255 * ts.userScreenBgOpacity).round());

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l.t('my_profile'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _toggleEdit,
                        child: Text(
                          l.t('cancel'),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.white.withAlpha(180),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.serviceRequestAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(70, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                l.t('save'),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  )
                : IconButton(
                    onPressed: _toggleEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppTheme.serviceRequestAccent,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(40),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoCard(l),
                      const SizedBox(height: 16),
                      _buildStatsCard(l),
                      const SizedBox(height: 16),
                      _buildActionsCard(l),
                      SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
                    ],
                  ),
                ),
                if (_isDeletingAccount)
                  Container(
                    color: screenBg.withAlpha(180),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            _nameController.text,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.serviceRequestAccent.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.t('customer'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.serviceRequestAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('personal_info'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - information fields
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      Icons.person_outline,
                      l.t('full_name'),
                      _nameController,
                      l: l,
                      enabled: false,
                    ),
                    _buildField(
                      Icons.email_outlined,
                      l.t('email'),
                      _emailController,
                      l: l,
                      enabled: _isEditing,
                    ),
                    _buildField(
                      Icons.phone_outlined,
                      l.t('phone'),
                      _phoneController,
                      l: l,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildField(
                      Icons.location_on_outlined,
                      l.t('address'),
                      _addressController,
                      l: l,
                      enabled: _isEditing,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side - avatar
              _buildAvatarWidget(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: Colors.white.withAlpha(40),
          backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
              ? NetworkImage(_avatarUrl!) as ImageProvider
              : null,
          onBackgroundImageError: _avatarUrl != null && _avatarUrl!.isNotEmpty
              ? (_, _) {}
              : null,
          child: _isUploadingAvatar
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : _avatarUrl == null || _avatarUrl!.isEmpty
                  ? Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text[0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.manrope(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.serviceRequestAccent,
                      ),
                    )
                  : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.serviceRequestAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController controller, {
    required LocalizationService l,
    bool enabled = false,
    bool isLast = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(180),
            ),
          ),
          const SizedBox(height: 6),
          enabled
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 18, color: Colors.white.withAlpha(180)),
                    filled: true,
                    fillColor: Colors.white.withAlpha(20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withAlpha(80)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withAlpha(80)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.serviceRequestAccent,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                )
              : Row(
                  children: [
                    Icon(icon, size: 18, color: Colors.white.withAlpha(180)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.text.isEmpty
                            ? l.t('not_set')
                            : controller.text,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: controller.text.isEmpty
                              ? Colors.white.withAlpha(120)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('activity'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem(
                '$_totalRequests',
                l.t('total_requests'),
                AppTheme.serviceRequestAccent,
                Colors.white.withAlpha(20),
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '$_completedRequests',
                l.t('done'),
                AppTheme.serviceRequestAccent,
                Colors.white.withAlpha(20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    Color color,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 11, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(LocalizationService l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemedAlertDialog(role: 'customer',
        backgroundColor: Colors.white.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha(80)),
        ),
        insetPadding: const EdgeInsets.fromLTRB(40, 40, 40, 90),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: AppTheme.error, size: 28),
            const SizedBox(width: 12),
            Text(
              l.t('delete_account'),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          l.t('delete_account_message'),
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white.withAlpha(180),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.t('cancel'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(180),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l.t('delete'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeletingAccount = true);
      try {
        final userId = SupabaseService.instance.currentUser?.id;
        if (userId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.t('error'))),
            );
          }
          return;
        }

        final result = await SupabaseService.instance.deleteUserAccount(userId);

        if (!mounted) return;

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('account_deleted'))),
          );
          await SupabaseService.instance.signOut();
          await ThemeService.instance.initialize();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.signUpLoginScreen,
              (r) => false,
            );
          }
        } else {
          final errorMsg = result['error']?.toString() ?? l.t('error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l.t('error')}: $errorMsg')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l.t('error')}: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeletingAccount = false);
        }
      }
    }
  }

  Widget _buildActionsCard(LocalizationService l) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Column(
        children: [
          _buildActionRow(
            Icons.directions_car_outlined,
            l.t('my_vehicle'),
            AppTheme.serviceRequestAccent,
            widget.onNavigateToMyVehicle ?? () {},
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.history_outlined,
            l.t('service_history'),
            AppTheme.serviceRequestAccent,
            widget.onNavigateToServiceHistory ?? () {},
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.help_outline_rounded,
            l.t('faq'),
            AppTheme.serviceRequestAccent,
            widget.onNavigateToFAQ ?? () {},
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.support_agent_outlined,
            l.t('support'),
            AppTheme.serviceRequestAccent,
            widget.onNavigateToSupport ?? () => Navigator.pushNamed(context, AppRoutes.supportTicketsScreen),
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.language,
            l.t('language'),
            AppTheme.serviceRequestAccent,
            () => CustomerLanguageDialog.show(context),
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.notifications_outlined,
            l.t('notifications'),
            AppTheme.serviceRequestAccent,
            () => _showNotificationSettings(),
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.delete_forever,
            l.t('delete_account'),
            AppTheme.error,
            () => _showDeleteAccountDialog(l),
          ),
          Divider(height: 1, color: Colors.white.withAlpha(40)),
          _buildActionRow(
            Icons.logout_rounded,
            l.t('sign_out'),
            AppTheme.error,
            () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => ThemedAlertDialog(role: 'customer',
                  backgroundColor: const Color(0xFF1A1A2E),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withAlpha(80)),
                  ),
                  insetPadding: const EdgeInsets.fromLTRB(40, 40, 40, 90),
                  title: Text(
                    l.t('sign_out'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  content: Text(
                    l.t('sign_out_confirmation'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        l.t('cancel'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        l.t('sign_out'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await SupabaseService.instance.signOut();
                await ThemeService.instance.initialize();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.signUpLoginScreen,
                    (r) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color == AppTheme.error
                      ? AppTheme.error
                      : Colors.white,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.white.withAlpha(180)),
          ],
        ),
      ),
    );
  }
}
