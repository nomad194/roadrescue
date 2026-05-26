import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminAppConfigWidget extends StatefulWidget {
  const AdminAppConfigWidget({super.key});

  @override
  State<AdminAppConfigWidget> createState() => _AdminAppConfigWidgetState();
}

class _AdminAppConfigWidgetState extends State<AdminAppConfigWidget>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;
  int _activeTabIndex = 0;

  final List<Map<String, dynamic>> _innerTabs = [
    {'label': 'General', 'icon': Icons.settings},
    {'label': 'API Keys', 'icon': Icons.key},
    {'label': 'Appearance', 'icon': Icons.palette},
    {'label': 'Social', 'icon': Icons.share},
    {'label': 'FAQs', 'icon': Icons.quiz},
    {'label': 'Content', 'icon': Icons.article},
  ];

  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  String _distanceUnit = 'mi';
  String _defaultLanguage = 'en';

  // Multilingual app name and tagline
  final Map<String, String> _appNameTranslations = {};
  final Map<String, String> _appTaglineTranslations = {};

  final _googleMapsKeyController = TextEditingController();
  final _stripeKeyController = TextEditingController();
  bool _showApiKeys = false;

  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;
  String _logoUrl = '';

  // Background settings
  Color? _bgColor;
  String _bgImageUrl = '';
  bool _bgIsImageMode = false; // false = color mode, true = image mode

  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();

  final List<Map<String, dynamic>> _faqs = [];
  final Map<String, String> _termsTranslations = {};
  final Map<String, String> _privacyTranslations = {};
  bool _enableOnboardingSlider = true;
  bool _showDemoCredentials = false;
  bool _showRoleSwitcher = true;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: _innerTabs.length, vsync: this);
    _innerTabController.addListener(() {
      if (!_innerTabController.indexIsChanging) {
        setState(() => _activeTabIndex = _innerTabController.index);
      }
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value');
      
      final Map<String, String> settings = {
        for (final row in response as List)
          row['setting_key'] as String: row['setting_value'] as String
      };

      if (mounted) {
        setState(() {
          if (settings.containsKey('app_name')) {
            final name = settings['app_name']!;
            _appNameTranslations['en'] = name;
          }
          if (settings.containsKey('app_tagline')) {
            final tagline = settings['app_tagline']!;
            _appTaglineTranslations['en'] = tagline;
          }
          if (settings.containsKey('app_name_translations')) {
            try {
              final decoded = json.decode(settings['app_name_translations']!) as Map<String, dynamic>;
              _appNameTranslations.clear();
              _appNameTranslations.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
            } catch (_) {}
          }
          if (settings.containsKey('app_tagline_translations')) {
            try {
              final decoded = json.decode(settings['app_tagline_translations']!) as Map<String, dynamic>;
              _appTaglineTranslations.clear();
              _appTaglineTranslations.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
            } catch (_) {}
          }
          if (settings.containsKey('support_email')) _supportEmailController.text = settings['support_email']!;
          if (settings.containsKey('support_phone')) _supportPhoneController.text = settings['support_phone']!;
          if (settings.containsKey('distance_unit')) _distanceUnit = settings['distance_unit']!;
          if (settings.containsKey('default_language')) _defaultLanguage = settings['default_language']!;

          if (settings.containsKey('google_maps_key')) _googleMapsKeyController.text = settings['google_maps_key']!;
          if (settings.containsKey('stripe_publishable_key')) _stripeKeyController.text = settings['stripe_publishable_key']!;

          if (settings.containsKey('logo_url')) _logoUrl = settings['logo_url']!;

          // Load background settings
          if (settings.containsKey('bg_color')) {
            final color = _parseHexColor(settings['bg_color']!);
            if (color != null) _bgColor = color;
          }
          if (settings.containsKey('bg_image_url')) _bgImageUrl = settings['bg_image_url']!;
          _bgIsImageMode = _bgImageUrl.isNotEmpty;
          
          if (settings.containsKey('primary_color')) {
            final color = _parseHexColor(settings['primary_color']!);
            if (color != null) _primaryColor = color;
          }
          if (settings.containsKey('secondary_color')) {
            final color = _parseHexColor(settings['secondary_color']!);
            if (color != null) _secondaryColor = color;
          }
          if (settings.containsKey('bg_color')) {
            final color = _parseHexColor(settings['bg_color']!);
            if (color != null) _bgColor = color;
          }

          if (settings.containsKey('facebook_url')) _facebookController.text = settings['facebook_url']!;
          if (settings.containsKey('instagram_url')) _instagramController.text = settings['instagram_url']!;
          if (settings.containsKey('twitter_url')) _twitterController.text = settings['twitter_url']!;

          if (settings.containsKey('terms_of_service')) {
            try {
              final Map<String, dynamic> decoded = json.decode(settings['terms_of_service']!);
              _termsTranslations.clear();
              _termsTranslations.addAll(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
            } catch (_) {
              _termsTranslations['en'] = settings['terms_of_service']!;
            }
          }

          if (settings.containsKey('privacy_policy')) {
            try {
              final Map<String, dynamic> decoded = json.decode(settings['privacy_policy']!);
              _privacyTranslations.clear();
              _privacyTranslations.addAll(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
            } catch (_) {
              _privacyTranslations['en'] = settings['privacy_policy']!;
            }
          }

          if (settings.containsKey('faq_content')) {
            try {
              final List decoded = json.decode(settings['faq_content']!);
              _faqs.clear();
              _faqs.addAll(decoded.map((f) => Map<String, dynamic>.from(f)));
            } catch (_) {}
          }

          if (settings.containsKey('enable_onboarding_slider')) {
            _enableOnboardingSlider = settings['enable_onboarding_slider'] == 'true';
          }
          if (settings.containsKey('show_demo_credentials')) {
            _showDemoCredentials = settings['show_demo_credentials'] == 'true';
          }
          if (settings.containsKey('show_role_switcher')) {
            _showRoleSwitcher = settings['show_role_switcher'] != 'false';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color? _parseHexColor(String hex) {
    try {
      if (hex.isEmpty) return null;
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) { return null; }
  }

  void _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final String primaryHex = '#${_primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      final String secondaryHex = '#${_secondaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      final String? bgHex = _bgColor != null
          ? '#${_bgColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
          : null;

      // Get default language values for backward compatibility
      final defaultAppName = _appNameTranslations[_defaultLanguage] ?? _appNameTranslations.values.firstOrNull ?? '';
      final defaultTagline = _appTaglineTranslations[_defaultLanguage] ?? _appTaglineTranslations.values.firstOrNull ?? '';

      // Add timeout to prevent hanging
      await Supabase.instance.client.from('app_settings').upsert([
        {'setting_key': 'app_name', 'setting_value': defaultAppName},
        {'setting_key': 'app_tagline', 'setting_value': defaultTagline},
        {'setting_key': 'app_name_translations', 'setting_value': json.encode(_appNameTranslations)},
        {'setting_key': 'app_tagline_translations', 'setting_value': json.encode(_appTaglineTranslations)},
        {'setting_key': 'support_email', 'setting_value': _supportEmailController.text.trim()},
        {'setting_key': 'support_phone', 'setting_value': _supportPhoneController.text.trim()},
        {'setting_key': 'distance_unit', 'setting_value': _distanceUnit},
        {'setting_key': 'default_language', 'setting_value': _defaultLanguage},
        {'setting_key': 'google_maps_key', 'setting_value': _googleMapsKeyController.text.trim()},
        {'setting_key': 'stripe_publishable_key', 'setting_value': _stripeKeyController.text.trim()},
        {'setting_key': 'logo_url', 'setting_value': _logoUrl},
        {'setting_key': 'primary_color', 'setting_value': primaryHex},
        {'setting_key': 'secondary_color', 'setting_value': secondaryHex},
        if (bgHex != null) {'setting_key': 'bg_color', 'setting_value': bgHex},
        {'setting_key': 'bg_image_url', 'setting_value': _bgImageUrl},
        {'setting_key': 'facebook_url', 'setting_value': _facebookController.text.trim()},
        {'setting_key': 'instagram_url', 'setting_value': _instagramController.text.trim()},
        {'setting_key': 'twitter_url', 'setting_value': _twitterController.text.trim()},
        {'setting_key': 'terms_of_service', 'setting_value': json.encode(_termsTranslations)},
        {'setting_key': 'privacy_policy', 'setting_value': json.encode(_privacyTranslations)},
        {'setting_key': 'faq_content', 'setting_value': json.encode(_faqs)},
        {'setting_key': 'enable_onboarding_slider', 'setting_value': _enableOnboardingSlider.toString()},
        {'setting_key': 'show_demo_credentials', 'setting_value': _showDemoCredentials.toString()},
        {'setting_key': 'show_role_switcher', 'setting_value': _showRoleSwitcher.toString()},
      ], onConflict: 'setting_key').timeout(const Duration(seconds: 10));

      // Update ThemeService with new settings
      ThemeService.instance.updateSettings(
        primary: _primaryColor,
        secondary: _secondaryColor,
        name: defaultAppName,
        tagline: defaultTagline,
        logo: _logoUrl,
        bgColor: _bgColor,
        bgImageUrl: _bgImageUrl,
        appNameTranslations: Map<String, String>.from(_appNameTranslations),
        appTaglineTranslations: Map<String, String>.from(_appTaglineTranslations),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating),
        );
      }
    } on TimeoutException {
      debugPrint('Save timed out');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save timed out. Please check your connection.'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
       debugPrint('Save error: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error),
         );
       }
    } finally { 
      if (mounted) setState(() => _isSaving = false); 
    }
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _googleMapsKeyController.dispose();
    _stripeKeyController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.t('app_config_title'), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(l.t('manage_settings'), style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(l.t('save_all')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 44),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _innerTabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: _innerTabs.map((t) => Tab(text: t['label'])).toList(),
        ),
        const SizedBox(height: 20),
        // HARDENED NAVIGATION: Using direct rendering instead of TabBarView to prevent infinite height crashes
        _buildActiveTabContent(),
      ],
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0: return _buildGeneralTab();
      case 1: return _buildApiKeysTab();
      case 2: return _buildAppearanceTab();
      case 3: return _buildSocialTab();
      case 4: return _buildFaqsTab();
      case 5: return _buildContentTab();
      default: return const Center(child: Text('Invalid Tab'));
    }
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Name - Multilingual
          _buildSectionCard(
            title: 'App Name',
            child: MultilingualTabsWidget(
              initialTranslations: _appNameTranslations,
              fieldLabel: 'App Name',
              hint: 'Enter app name...',
              onChanged: (updated) {
                setState(() {
                  _appNameTranslations.clear();
                  _appNameTranslations.addAll(updated);
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          // App Tagline - Multilingual
          _buildSectionCard(
            title: 'App Tagline',
            child: MultilingualTabsWidget(
              initialTranslations: _appTaglineTranslations,
              fieldLabel: 'App Tagline',
              hint: 'Enter app tagline...',
              onChanged: (updated) {
                setState(() {
                  _appTaglineTranslations.clear();
                  _appTaglineTranslations.addAll(updated);
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField('Support Email', _supportEmailController),
          _buildTextField('Support Phone', _supportPhoneController),
          const SizedBox(height: 4),
          _buildToggleRow(
            icon: Icons.badge_outlined,
            title: 'Show Demo Credentials',
            subtitle: 'Display demo login credentials on the login screen',
            value: _showDemoCredentials,
            onChanged: (v) => setState(() => _showDemoCredentials = v),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Show Role Switcher',
            subtitle: 'Allow users to switch between Driver/Provider views',
            value: _showRoleSwitcher,
            onChanged: (v) => setState(() => _showRoleSwitcher = v),
          ),
          const SizedBox(height: 16),
          Text('Distance Unit', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'mi', label: Text('Miles')),
              ButtonSegment(value: 'km', label: Text('Kilometers')),
            ],
            selected: {_distanceUnit},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _distanceUnit = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Theme.of(context).primaryColor,
              selectedForegroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text('Default App Language', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _defaultLanguage,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: LocalizationService.supportedLanguages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _defaultLanguage = v!),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildApiKeysTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Show Keys'),
            const Spacer(),
            Switch(value: _showApiKeys, onChanged: (v) => setState(() => _showApiKeys = v)),
          ],
        ),
        _buildTextField('Google Maps API Key', _googleMapsKeyController, obscure: !_showApiKeys),
        _buildTextField('Stripe Publishable Key', _stripeKeyController, obscure: !_showApiKeys),
      ],
    );
  }

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Image Picker
          _buildSectionCard(
            title: 'App Logo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_logoUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _logoUrl,
                      height: 80,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 80,
                        child: Center(child: Icon(Icons.error_outline, color: AppTheme.error)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _pickLogoImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(_logoUrl.isEmpty ? 'Upload Logo' : 'Change Logo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_logoUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() => _logoUrl = ''),
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.error),
                        label: const Text('Remove', style: TextStyle(color: AppTheme.error)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Brand Color
          _buildAdvancedColorPicker(
            'Primary Brand Color',
            _primaryColor,
            (color) => setState(() => _primaryColor = color),
          ),
          const SizedBox(height: 16),

          // Secondary Brand Color
          _buildAdvancedColorPicker(
            'Secondary Brand Color',
            _secondaryColor,
            (color) => setState(() => _secondaryColor = color),
          ),
          const SizedBox(height: 16),

          // Background Settings
          _buildSectionCard(
            title: 'Background Style',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Color')),
                    ButtonSegment(value: true, label: Text('Image')),
                  ],
                  selected: {_bgIsImageMode},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _bgIsImageMode = newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: Theme.of(context).primaryColor,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_bgIsImageMode)
                  _buildAdvancedColorPicker(
                    'Background Color',
                    _bgColor ?? Colors.white,
                    (color) => setState(() => _bgColor = color),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_bgImageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _bgImageUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 100,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => const SizedBox(
                              height: 100,
                              child: Center(child: Icon(Icons.error_outline, color: AppTheme.error)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _pickBgImage,
                            icon: const Icon(Icons.wallpaper_outlined, size: 18),
                            label: Text(_bgImageUrl.isEmpty ? 'Upload Background' : 'Change Background'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          if (_bgImageUrl.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() => _bgImageUrl = ''),
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.error),
                              label: const Text('Remove', style: TextStyle(color: AppTheme.error)),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickLogoImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
      if (picked == null) return;

      setState(() => _isSaving = true);

      String? publicUrl;
      if (kIsWeb) {
        // For web, upload bytes
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final storagePath = 'logo/logo.$ext';
        await Supabase.instance.client.storage
            .from('app-assets')
            .uploadBinary(storagePath, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));
        publicUrl = Supabase.instance.client.storage.from('app-assets').getPublicUrl(storagePath);
      } else {
        // For mobile/desktop, upload file
        publicUrl = await SupabaseService.instance.uploadAppAsset('app-assets', 'logo/logo', picked.path);
      }

      if (publicUrl != null) {
        setState(() => _logoUrl = publicUrl!);
      }
    } catch (e) {
      debugPrint('Logo upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBgImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isSaving = true);

      String? publicUrl;
      if (kIsWeb) {
        // For web, upload bytes
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        final storagePath = 'bg/background.$ext';
        await Supabase.instance.client.storage
            .from('app-assets')
            .uploadBinary(storagePath, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));
        publicUrl = Supabase.instance.client.storage.from('app-assets').getPublicUrl(storagePath);
      } else {
        // For mobile/desktop, upload file
        publicUrl = await SupabaseService.instance.uploadAppAsset('app-assets', 'bg/background', picked.path);
      }

      if (publicUrl != null) {
        setState(() => _bgImageUrl = publicUrl!);
      }
    } catch (e) {
      debugPrint('Background upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload background: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAdvancedColorPicker(String label, Color currentColor, ValueChanged<Color> onColorChanged) {
    return _buildSectionCard(
      title: label,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Current color swatch
          GestureDetector(
            onTap: () => _showColorPickerDialog(label, currentColor, onColorChanged),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outline, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withAlpha(60),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Hex value display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outline),
            ),
            child: Text(
              '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          // Edit button
          ElevatedButton.icon(
            onPressed: () => _showColorPickerDialog(label, currentColor, onColorChanged),
            icon: const Icon(Icons.colorize, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    Color pickerColor = currentColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
              hexInputBar: true,
              colorPickerWidth: 300,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onColorChanged(pickerColor);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return Column(
      children: [
        _buildTextField('Facebook URL', _facebookController),
        _buildTextField('Instagram URL', _instagramController),
        _buildTextField('Twitter URL', _twitterController),
      ],
    );
  }

  Widget _buildFaqsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'FAQs',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: ElevatedButton.icon(
                onPressed: () => _showFaqDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add FAQ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_faqs.isEmpty)
          _buildEmptyContentPlaceholder('No FAQs added yet. Click "Add FAQ" to start.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _faqs.length,
            itemBuilder: (context, index) => _buildFaqCard(index, _faqs[index]),
          ),
      ],
    );
  }

  Widget _buildContentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Onboarding Slider', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(value: _enableOnboardingSlider, onChanged: (v) => setState(() => _enableOnboardingSlider = v)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Terms of Service',
          child: MultilingualTabsWidget(
            initialTranslations: _termsTranslations,
            fieldLabel: 'Terms of Service',
            hint: 'Enter legal terms...',
            maxLines: 8,
            onChanged: (updated) {
              setState(() {
                _termsTranslations.clear();
                _termsTranslations.addAll(updated);
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Privacy Policy',
          child: MultilingualTabsWidget(
            initialTranslations: _privacyTranslations,
            fieldLabel: 'Privacy Policy',
            hint: 'Enter privacy terms...',
            maxLines: 8,
            onChanged: (updated) {
              setState(() {
                _privacyTranslations.clear();
                _privacyTranslations.addAll(updated);
              });
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyContentPlaceholder(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.quiz_outlined, size: 32, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFaqCard(int index, Map<String, dynamic> faq) {
    final l = LocalizationService.instance;
    final question = l.translateContent(faq['translations_q'] ?? {}, fallbackText: 'No Question');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(question, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: const Text('Tap to edit translations', style: TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
              onPressed: () => _showFaqDialog(index: index, faq: faq),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
              onPressed: () => setState(() => _faqs.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFaqDialog({int? index, Map<String, dynamic>? faq}) {
    Map<String, String> qTrans = Map<String, String>.from(faq?['translations_q'] ?? {});
    Map<String, String> aTrans = Map<String, String>.from(faq?['translations_a'] ?? {});

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? 'Add FAQ' : 'Edit FAQ', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MultilingualTabsWidget(
                  initialTranslations: qTrans,
                  fieldLabel: 'Question',
                  hint: 'Enter question...',
                  onChanged: (updated) => qTrans = updated,
                ),
                const SizedBox(height: 20),
                MultilingualTabsWidget(
                  initialTranslations: aTrans,
                  fieldLabel: 'Answer',
                  hint: 'Enter answer...',
                  maxLines: 4,
                  onChanged: (updated) => aTrans = updated,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final newFaq = {
                  'translations_q': qTrans,
                  'translations_a': aTrans,
                };
                if (index == null) {
                  _faqs.add(newFaq);
                } else {
                  _faqs[index] = newFaq;
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle, style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
