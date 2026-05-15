import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/language_selector_widget.dart';
import '../../services/localization_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _nameController = TextEditingController(text: 'Marcus Johnson');
  final _emailController = TextEditingController(
    text: 'marcus.johnson@email.com',
  );
  final _phoneController = TextEditingController(text: '+1 (512) 555-0174');
  final _addressController = TextEditingController(
    text: '4721 Maple Ave, Austin, TX',
  );

  final String _profileImageUrl =
      'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
  }

  void _saveProfile() {
    setState(() => _isSaving = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.t('profile_updated'),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppTheme.onSurface,
          ),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.serviceRequestScreen,
            (r) => false,
          ),
        ),
        title: Text(
          l.t('my_profile'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        actions: [
          const LanguageSelectorWidget(),
          const SizedBox(width: 8),
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
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
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
                                  color: Colors.white,
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
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(l),
            const SizedBox(height: 20),
            _buildInfoCard(l),
            const SizedBox(height: 16),
            _buildStatsCard(l),
            const SizedBox(height: 16),
            _buildActionsCard(l),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primaryContainer,
                backgroundImage: NetworkImage(_profileImageUrl),
                onBackgroundImageError: (_, __) {},
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : 'U',
                  style: GoogleFonts.manrope(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _nameController.text,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.t('customer'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('personal_info'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            Icons.person_outline,
            l.t('full_name'),
            _nameController,
            l: l,
            enabled: _isEditing,
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
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          enabled
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 18, color: AppTheme.muted),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
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
                    color: AppTheme.onSurface,
                  ),
                )
              : Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.text.isEmpty ? l.t('not_set') : controller.text,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: controller.text.isEmpty
                              ? AppTheme.muted
                              : AppTheme.onSurface,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('activity'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem(
                '12',
                l.t('total_requests'),
                AppTheme.primary,
                AppTheme.primaryContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '10',
                l.t('done'),
                AppTheme.success,
                AppTheme.successContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '4.8',
                l.t('rating'),
                AppTheme.warning,
                AppTheme.warningContainer,
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

  Widget _buildActionsCard(LocalizationService l) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildActionRow(
            Icons.history_outlined,
            l.t('service_history'),
            AppTheme.primary,
            () => Navigator.pushNamed(context, AppRoutes.serviceHistoryScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.help_outline_rounded,
            l.t('faq'),
            AppTheme.primary,
            () => Navigator.pushNamed(context, AppRoutes.faqTosScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.language,
            l.t('language'),
            AppTheme.primary,
            () => LanguageSelectorWidget.showLanguageDialog(context),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.notifications_outlined,
            l.t('notifications'),
            AppTheme.primary,
            () {},
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.logout_rounded,
            l.t('sign_out'),
            AppTheme.error,
            () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.signUpLoginScreen,
              (r) => false,
            ),
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
                      : AppTheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
