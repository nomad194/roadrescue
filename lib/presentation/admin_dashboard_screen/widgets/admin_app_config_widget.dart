import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminAppConfigWidget extends StatefulWidget {
  const AdminAppConfigWidget({super.key});

  @override
  State<AdminAppConfigWidget> createState() => _AdminAppConfigWidgetState();
}

class _AdminAppConfigWidgetState extends State<AdminAppConfigWidget>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;

  final List<Map<String, String>> _innerTabs = [
    {'label': 'General', 'icon': 'settings'},
    {'label': 'API Keys', 'icon': 'key'},
    {'label': 'Appearance', 'icon': 'palette'},
    {'label': 'Social', 'icon': 'share'},
    {'label': 'Content', 'icon': 'article'},
  ];

  final _appNameController = TextEditingController(text: 'RoadRescue');
  final _appTaglineController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  String _distanceUnit = 'mi';

  final _googleMapsKeyController = TextEditingController();
  final _stripeKeyController = TextEditingController();
  bool _showApiKeys = false;

  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;
  final _logoUrlController = TextEditingController();

  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();

  final List<Map<String, dynamic>> _faqs = [];
  final Map<String, String> _termsTranslations = {};

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: _innerTabs.length, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
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
          if (settings.containsKey('app_name')) _appNameController.text = settings['app_name']!;
          if (settings.containsKey('app_tagline')) _appTaglineController.text = settings['app_tagline']!;
          if (settings.containsKey('support_email')) _supportEmailController.text = settings['support_email']!;
          if (settings.containsKey('support_phone')) _supportPhoneController.text = settings['support_phone']!;
          if (settings.containsKey('distance_unit')) _distanceUnit = settings['distance_unit']!;
          
          if (settings.containsKey('google_maps_key')) _googleMapsKeyController.text = settings['google_maps_key']!;
          if (settings.containsKey('stripe_publishable_key')) _stripeKeyController.text = settings['stripe_publishable_key']!;

          if (settings.containsKey('logo_url')) _logoUrlController.text = settings['logo_url']!;
          if (settings.containsKey('primary_color')) {
            _primaryColor = _parseHexColor(settings['primary_color']!) ?? AppTheme.primary;
          }
          if (settings.containsKey('secondary_color')) {
            _secondaryColor = _parseHexColor(settings['secondary_color']!) ?? AppTheme.secondary;
          }

          if (settings.containsKey('facebook_url')) _facebookController.text = settings['facebook_url']!;
          if (settings.containsKey('instagram_url')) _instagramController.text = settings['instagram_url']!;
          if (settings.containsKey('twitter_url')) _twitterController.text = settings['twitter_url']!;

          if (settings.containsKey('terms_of_service')) {
             _termsTranslations['en'] = settings['terms_of_service']!;
          }
          if (settings.containsKey('faq_content')) {
            try {
              final List decoded = json.decode(settings['faq_content']!);
              _faqs.clear();
              _faqs.addAll(decoded.map((f) => Map<String, dynamic>.from(f)));
            } catch (_) {}
          }
        });
      }
    } catch (_) {}
  }

  Color? _parseHexColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) { return null; }
  }

  bool _isSaving = false;

  void _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final String primaryHex = '#${_primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      final String secondaryHex = '#${_secondaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

      await Supabase.instance.client.from('app_settings').upsert([
        {'setting_key': 'app_name', 'setting_value': _appNameController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'app_tagline', 'setting_value': _appTaglineController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'support_email', 'setting_value': _supportEmailController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'support_phone', 'setting_value': _supportPhoneController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'distance_unit', 'setting_value': _distanceUnit, 'setting_type': 'text'},
        {'setting_key': 'google_maps_key', 'setting_value': _googleMapsKeyController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'stripe_publishable_key', 'setting_value': _stripeKeyController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'logo_url', 'setting_value': _logoUrlController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'primary_color', 'setting_value': primaryHex, 'setting_type': 'text'},
        {'setting_key': 'secondary_color', 'setting_value': secondaryHex, 'setting_type': 'text'},
        {'setting_key': 'facebook_url', 'setting_value': _facebookController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'instagram_url', 'setting_value': _instagramController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'twitter_url', 'setting_value': _twitterController.text.trim(), 'setting_type': 'text'},
        {'setting_key': 'terms_of_service', 'setting_value': _termsTranslations['en'] ?? '', 'setting_type': 'text'},
        {'setting_key': 'faq_content', 'setting_value': json.encode(_faqs), 'setting_type': 'json'},
      ], onConflict: 'setting_key');
      
      ThemeService.instance.updateSettings(
        primary: _primaryColor, 
        secondary: _secondaryColor,
        name: _appNameController.text.trim(),
        tagline: _appTaglineController.text.trim(),
        logo: _logoUrlController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
       debugPrint('Save error: $e');
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    _appNameController.dispose();
    _appTaglineController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _googleMapsKeyController.dispose();
    _stripeKeyController.dispose();
    _logoUrlController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('app_config_title'), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(l.t('manage_settings'), style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant)),
              ],
            ),
            ElevatedButton.icon(
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
        SizedBox(
          height: 500,
          child: TabBarView(
            controller: _innerTabController,
            children: [
              _buildGeneralTab(),
              _buildApiKeysTab(),
              _buildAppearanceTab(),
              _buildSocialTab(),
              _buildContentTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('App Name', _appNameController),
          _buildTextField('App Tagline', _appTaglineController),
          _buildTextField('Support Email', _supportEmailController),
          _buildTextField('Support Phone', _supportPhoneController),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildApiKeysTab() {
    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Logo URL', _logoUrlController),
          const SizedBox(height: 16),
          _buildColorPicker('Primary Brand Color', _primaryColor, (c) => setState(() => _primaryColor = c)),
          const SizedBox(height: 24),
          _buildColorPicker('Secondary Brand Color', _secondaryColor, (c) => setState(() => _secondaryColor = c)),
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTextField('Facebook URL', _facebookController),
          _buildTextField('Instagram URL', _instagramController),
          _buildTextField('Twitter URL', _twitterController),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FAQs', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showFaqDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add FAQ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_faqs.isEmpty)
            _buildEmptyContentPlaceholder('No FAQs added yet. Click "Add FAQ" to start.')
          else
            ..._faqs.asMap().entries.map((e) => _buildFaqCard(e.key, e.value)),
        ],
      ),
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
        children: [
          Icon(Icons.article_outlined, size: 32, color: AppTheme.muted),
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
          width: double.maxFinite,
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

  Widget _buildColorPicker(String label, Color current, ValueChanged<Color> onSelect) {
    final colors = [
      const Color(0xFF1A56DB),
      const Color(0xFF7C3AED),
      const Color(0xFF16A34A),
      const Color(0xFFDC2626),
      const Color(0xFFF97316),
      const Color(0xFF0891B2),
      const Color(0xFF9D174D),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) => GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: current.toARGB32() == c.toARGB32() ? AppTheme.onSurface : Colors.transparent, width: 3),
                boxShadow: [if (current.toARGB32() == c.toARGB32()) BoxShadow(color: c.withAlpha(80), blurRadius: 8, spreadRadius: 2)],
              ),
              child: current.toARGB32() == c.toARGB32() ? const Icon(Icons.check, color: Colors.white) : null,
            ),
          )).toList(),
        ),
      ],
    );
  }
}
