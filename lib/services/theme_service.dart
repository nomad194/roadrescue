import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;
  String _appName = 'RoadRescue';
  String _appTagline = 'Roadside Assistance On Demand';
  String _logoUrl = '';

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  String get appName => _appName;
  String get appTagline => _appTagline;
  String get logoUrl => _logoUrl;

  Future<void> initialize() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', [
            'primary_color', 
            'secondary_color', 
            'app_name', 
            'app_tagline', 
            'logo_url'
          ]);

      for (final row in response) {
        final key = row['setting_key'];
        final value = row['setting_value'] as String;
        
        if (key == 'app_name' && value.isNotEmpty) _appName = value;
        if (key == 'app_tagline' && value.isNotEmpty) _appTagline = value;
        if (key == 'logo_url') _logoUrl = value;

        final color = _parseHexColor(value);
        if (color != null) {
          if (key == 'primary_color') _primaryColor = color;
          if (key == 'secondary_color') _secondaryColor = color;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void updateSettings({Color? primary, Color? secondary, String? name, String? tagline, String? logo}) {
    if (primary != null) _primaryColor = primary;
    if (secondary != null) _secondaryColor = secondary;
    if (name != null) _appName = name;
    if (tagline != null) _appTagline = tagline;
    if (logo != null) _logoUrl = logo;
    notifyListeners();
  }

  Color? _parseHexColor(String hex) {
    try {
      if (!hex.startsWith('#')) return null;
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
