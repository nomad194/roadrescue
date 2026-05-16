import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/language_selector_widget.dart';
import '../../services/localization_service.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAvailable = true;

  final _nameController = TextEditingController(text: 'Carlos Rivera');
  final _emailController = TextEditingController(
    text: 'carlos.rivera@provider.com',
  );
  final _phoneController = TextEditingController(text: '+1 (512) 555-0291');
  final _businessNameController = TextEditingController(
    text: 'Rivera Roadside Services',
  );
  final _businessImageController = TextEditingController(
    text: 'https://images.pexels.com/photos/3807386/pexels-photo-3807386.jpeg',
  );
  final _serviceRangeController = TextEditingController(text: '25');
  final _addressController = TextEditingController(text: 'Austin, TX 78701');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessImageController.dispose();
    _serviceRangeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  void _saveProfile() {
    final l = LocalizationService.instance;
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
            l.t('profile_updated'),
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
            AppRoutes.jobRequestsScreen,
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
            _buildAvailabilityBanner(l),
            const SizedBox(height: 16),
            _buildProfileHeader(l),
            const SizedBox(height: 16),
            _buildBusinessCard(l),
            const SizedBox(height: 16),
            _buildPersonalInfoCard(l),
            const SizedBox(height: 16),
            _buildServiceRangeCard(l),
            const SizedBox(height: 16),
            _buildStatsCard(l),
            const SizedBox(height: 16),
            _buildActionsCard(l),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBanner(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isAvailable
            ? AppTheme.successContainer
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isAvailable
              ? AppTheme.success.withAlpha(80)
              : AppTheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isAvailable ? AppTheme.success : AppTheme.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? l.t('available') : l.t('unavailable'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isAvailable
                        ? AppTheme.success
                        : AppTheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _isAvailable
                      ? l.t('customers_can_see_you')
                      : l.t('unavailable_info'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: _isAvailable ? AppTheme.success : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (v) {
              setState(() => _isAvailable = v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    v
                        ? l.t('available_msg')
                        : l.t('unavailable_msg'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: v
                      ? AppTheme.success
                      : AppTheme.onSurfaceVariant,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            activeThumbColor: AppTheme.success,
          ),
        ],
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
                backgroundImage: NetworkImage(_businessImageController.text),
                onBackgroundImageError: (_, __) {},
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : 'P',
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
          Text(
            _businessNameController.text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.t('provider'),
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

  Widget _buildBusinessCard(LocalizationService l) {
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
            l.t('business_info'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            Icons.business_outlined,
            l.t('business_name'),
            _businessNameController,
            l: l,
            enabled: _isEditing,
          ),
          _buildField(
            Icons.image_outlined,
            l.t('business_image_url'),
            _businessImageController,
            l: l,
            enabled: _isEditing,
            isLast: true,
          ),
          if (_isEditing && _businessImageController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _businessImageController.text,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(LocalizationService l) {
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

  Widget _buildServiceRangeCard(LocalizationService l) {
    final rangeValue = double.tryParse(_serviceRangeController.text) ?? 25.0;
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
          Row(
            children: [
              const Icon(Icons.radar, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                l.t('service_range'),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rangeValue.toInt()} ${l.t('miles_radius')}',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      l.t('from_base_location'),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 28,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 14),
            Text(
              l.t('adjust_range'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '5 mi',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: rangeValue.clamp(5, 100),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.outlineVariant,
                    onChanged: (v) => setState(
                      () => _serviceRangeController.text = v.toInt().toString(),
                    ),
                  ),
                ),
                Text(
                  '100 mi',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ],
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
            l.t('performance'),
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
                '47',
                l.t('jobs_done'),
                AppTheme.primary,
                AppTheme.primaryContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '4.9',
                l.t('rating'),
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '98%',
                l.t('accept_rate'),
                AppTheme.success,
                AppTheme.successContainer,
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
            Icons.card_membership,
            l.t('subscription_plans'),
            AppTheme.primary,
            () =>
                Navigator.pushReplacementNamed(context, AppRoutes.jobRequestsScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.build_circle_outlined,
            l.t('my_services_pricing'),
            AppTheme.primary,
            () =>
                Navigator.pushReplacementNamed(context, AppRoutes.jobRequestsScreen),
          ),
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
