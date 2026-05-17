import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;

  Future<void> initialize() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', ['primary_color', 'secondary_color']);

      for (final row in response) {
        final key = row['setting_key'];
        final value = row['setting_value'] as String;
        final color = _parseHexColor(value);
        if (color != null) {
          if (key == 'primary_color') _primaryColor = color;
          if (key == 'secondary_color') _secondaryColor = color;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void updateColors({Color? primary, Color? secondary}) {
    if (primary != null) _primaryColor = primary;
    if (secondary != null) _secondaryColor = secondary;
    notifyListeners();
  }

  Color? _parseHexColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
