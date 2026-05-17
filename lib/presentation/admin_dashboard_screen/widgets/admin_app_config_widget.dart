import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/theme_service.dart';

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
    {'label': 'Appearance', 'icon': 'palette'},
    {'label': 'Content', 'icon': 'article'},
    {'label': 'Languages', 'icon': 'language'},
  ];

  final _appNameController = TextEditingController(text: 'RoadRescue');
  String _distanceUnit = 'mi';

  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;

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
          if (settings.containsKey('distance_unit')) _distanceUnit = settings['distance_unit']!;
          
          if (settings.containsKey('primary_color')) {
            _primaryColor = _parseHexColor(settings['primary_color']!) ?? AppTheme.primary;
          }
          if (settings.containsKey('secondary_color')) {
            _secondaryColor = _parseHexColor(settings['secondary_color']!) ?? AppTheme.secondary;
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
        {'setting_key': 'primary_color', 'setting_value': primaryHex, 'setting_type': 'text'},
        {'setting_key': 'secondary_color', 'setting_value': secondaryHex, 'setting_type': 'text'},
        {'setting_key': 'distance_unit', 'setting_value': _distanceUnit, 'setting_type': 'text'},
      ], onConflict: 'setting_key');
      
      ThemeService.instance.updateColors(primary: _primaryColor, secondary: _secondaryColor);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating),
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
          height: 400,
          child: TabBarView(
            controller: _innerTabController,
            children: [
              _buildGeneralTab(),
              _buildAppearanceTab(),
              const Center(child: Text('Content Management')),
              const Center(child: Text('Language Settings')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('App Name', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: _appNameController, decoration: const InputDecoration(hintText: 'Enter App Name')),
        const SizedBox(height: 20),
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
    );
  }

  Widget _buildAppearanceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorPicker('Primary Brand Color', _primaryColor, (c) => setState(() => _primaryColor = c)),
        const SizedBox(height: 24),
        _buildColorPicker('Secondary Brand Color', _secondaryColor, (c) => setState(() => _secondaryColor = c)),
      ],
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
