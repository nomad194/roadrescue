import 'dart:convert';
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
  Color? _bgColor;
  String _bgImageUrl = '';
  Map<String, String> _appNameTranslations = {};
  Map<String, String> _appTaglineTranslations = {};

  // Provider main screen settings
  Color _providerMainScreenBg = AppTheme.surface;
  double _providerMainScreenBgOpacity = 1.0;
  String _providerMainScreenBgImageUrl = '';
  double _providerMainHeaderOpacity = 1.0;
  Color _providerMainHeaderGradientStart = const Color(0xFF1A56DB);
  Color _providerMainHeaderGradientEnd = const Color(0xFF7C3AED);
  Color _providerMainHeaderTextColor = Colors.white;
  Color _providerMainAvailableColor = const Color(0xFF4ADE80);
  Color _providerMainUnavailableColor = const Color(0xFFF87171);
  Color _providerMainHeaderIconBtnBg = Colors.white24;
  Color _providerMainHeaderIconBtnIcon = Colors.white;
  Color _providerMainCardBg = Colors.white;
  Color _providerMainCardBorder = const Color(0xFFE5E7EB);
  Color _providerMainUrgentBorder = const Color(0xFFF59E0B);
  Color _providerMainActionBtnBg = const Color(0xFF1A56DB);
  Color _providerMainActionBtnText = Colors.white;
  Color _providerMainSecondaryActionBtnBg = const Color(0xFFE5E7EB);
  Color _providerMainTabSelectedBg = const Color(0xFF1A56DB);
  Color _providerMainTabUnselectedBg = Colors.transparent;
  Color _providerMainTabSelectedText = Colors.white;
  Color _providerMainTabUnselectedText = const Color(0xFF6B7280);

  // Login/Signup screen settings (role-specific)
  final Map<String, dynamic> _loginScreenSettings = {};

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  String get appName => _appName;
  String get appTagline => _appTagline;
  String get logoUrl => _logoUrl;
  Color? get bgColor => _bgColor;
  String get bgImageUrl => _bgImageUrl;
  Map<String, String> get appNameTranslations => _appNameTranslations;
  Map<String, String> get appTaglineTranslations => _appTaglineTranslations;

  // Provider main screen getters
  Color get providerMainScreenBg => _providerMainScreenBg;
  double get providerMainScreenBgOpacity => _providerMainScreenBgOpacity;
  String get providerMainScreenBgImageUrl => _providerMainScreenBgImageUrl;
  double get providerMainHeaderOpacity => _providerMainHeaderOpacity;
  Color get providerMainHeaderGradientStart => _providerMainHeaderGradientStart;
  Color get providerMainHeaderGradientEnd => _providerMainHeaderGradientEnd;
  Color get providerMainHeaderTextColor => _providerMainHeaderTextColor;
  Color get providerMainAvailableColor => _providerMainAvailableColor;
  Color get providerMainUnavailableColor => _providerMainUnavailableColor;
  Color get providerMainHeaderIconBtnBg => _providerMainHeaderIconBtnBg;
  Color get providerMainHeaderIconBtnIcon => _providerMainHeaderIconBtnIcon;
  Color get providerMainCardBg => _providerMainCardBg;
  Color get providerMainCardBorder => _providerMainCardBorder;
  Color get providerMainUrgentBorder => _providerMainUrgentBorder;
  Color get providerMainActionBtnBg => _providerMainActionBtnBg;
  Color get providerMainActionBtnText => _providerMainActionBtnText;
  Color get providerMainSecondaryActionBtnBg => _providerMainSecondaryActionBtnBg;
  Color get providerMainTabSelectedBg => _providerMainTabSelectedBg;
  Color get providerMainTabUnselectedBg => _providerMainTabUnselectedBg;
  Color get providerMainTabSelectedText => _providerMainTabSelectedText;
  Color get providerMainTabUnselectedText => _providerMainTabUnselectedText;

  /// Get localized app name based on language code (fallback to default)
  String getLocalizedAppName(String languageCode) {
    return _appNameTranslations[languageCode] ??
           _appNameTranslations.values.firstOrNull ??
           _appName;
  }

  /// Get localized tagline based on language code (fallback to default)
  String getLocalizedTagline(String languageCode) {
    return _appTaglineTranslations[languageCode] ??
           _appTaglineTranslations.values.firstOrNull ??
           _appTagline;
  }

  // Login/signup role-specific methods
  Color? getBgColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_bg_color';
    final val = _loginScreenSettings[key] as String?;
    return val != null ? _parseHexColor(val) : _bgColor;
  }

  String getBgImageUrlFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_bg_image_url';
    return (_loginScreenSettings[key] as String?) ?? _bgImageUrl;
  }

  String getLogoFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_logo_url';
    return (_loginScreenSettings[key] as String?) ?? _logoUrl;
  }

  Color getHeaderColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_header_color';
    final val = _loginScreenSettings[key] as String?;
    return (val != null ? _parseHexColor(val) : null) ?? _primaryColor;
  }

  double getHeaderOpacityFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_header_opacity';
    final val = _loginScreenSettings[key] as String?;
    return val != null ? (double.tryParse(val) ?? 1.0) : 1.0;
  }

  String getHeadingFor({required String role, required bool isLogin, required String languageCode}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_heading';
    final val = _loginScreenSettings[key] as String?;
    if (val == null || val.isEmpty) return '';
    try {
      final decoded = json.decode(val) as Map<String, dynamic>;
      return decoded[languageCode]?.toString() ?? decoded['en']?.toString() ?? '';
    } catch (_) {
      return val;
    }
  }

  String getSubtitleFor({required String role, required bool isLogin, required String languageCode}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_subtitle';
    final val = _loginScreenSettings[key] as String?;
    if (val == null || val.isEmpty) return '';
    try {
      final decoded = json.decode(val) as Map<String, dynamic>;
      return decoded[languageCode]?.toString() ?? decoded['en']?.toString() ?? '';
    } catch (_) {
      return val;
    }
  }

  Color getHeadingTextColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_heading_text_color';
    final val = _loginScreenSettings[key] as String?;
    return (val != null ? _parseHexColor(val) : null) ?? AppTheme.onSurface;
  }

  Color getSubtitleTextColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_subtitle_text_color';
    final val = _loginScreenSettings[key] as String?;
    return (val != null ? _parseHexColor(val) : null) ?? AppTheme.onSurfaceVariant;
  }

  Color getMainButtonBgColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_bg';
    final val = _loginScreenSettings[key] as String?;
    return (val != null ? _parseHexColor(val) : null) ?? _primaryColor;
  }

  Color getMainButtonTextColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_text';
    final val = _loginScreenSettings[key] as String?;
    return (val != null ? _parseHexColor(val) : null) ?? Colors.white;
  }

  Color? getMainButtonGlowColorFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_glow';
    final val = _loginScreenSettings[key] as String?;
    return val != null ? _parseHexColor(val) : null;
  }

  double getMainButtonBorderRadiusFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_border_radius';
    final val = _loginScreenSettings[key] as String?;
    return val != null ? (double.tryParse(val) ?? 12.0) : 12.0;
  }

  String getMainButtonShadowFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_shadow';
    return (_loginScreenSettings[key] as String?) ?? 'medium';
  }

  String getMainButtonAnimationFor({required String role, required bool isLogin}) {
    final key = '${role}_${isLogin ? 'login' : 'signup'}_main_btn_animation';
    return (_loginScreenSettings[key] as String?) ?? 'none';
  }

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
            'logo_url',
            'bg_color',
            'bg_image_url',
            'app_name_translations',
            'app_tagline_translations',
            // Provider main screen settings
            'provider_main_screen_bg',
            'provider_main_screen_bg_opacity',
            'provider_main_screen_bg_image_url',
            'provider_main_header_opacity',
            'provider_main_header_gradient_start',
            'provider_main_header_gradient_end',
            'provider_main_header_text_color',
            'provider_main_available_color',
            'provider_main_unavailable_color',
            'provider_main_header_icon_btn_bg',
            'provider_main_header_icon_btn_icon',
            'provider_main_card_bg',
            'provider_main_card_border',
            'provider_main_urgent_border',
            'provider_main_action_btn_bg',
            'provider_main_action_btn_text',
            'provider_main_secondary_action_btn_bg',
            'provider_main_tab_selected_bg',
            'provider_main_tab_unselected_bg',
            'provider_main_tab_selected_text',
            'provider_main_tab_unselected_text',
            // Login/signup role-specific settings
            'customer_login_bg_color',
            'customer_login_bg_image_url',
            'customer_login_logo_url',
            'customer_login_header_color',
            'customer_login_header_opacity',
            'customer_login_heading',
            'customer_login_subtitle',
            'customer_login_heading_text_color',
            'customer_login_subtitle_text_color',
            'customer_login_main_btn_bg',
            'customer_login_main_btn_text',
            'customer_login_main_btn_glow',
            'customer_login_main_btn_border_radius',
            'customer_login_main_btn_shadow',
            'customer_login_main_btn_animation',
            'customer_signup_bg_color',
            'customer_signup_bg_image_url',
            'customer_signup_logo_url',
            'customer_signup_header_color',
            'customer_signup_header_opacity',
            'customer_signup_heading',
            'customer_signup_subtitle',
            'customer_signup_heading_text_color',
            'customer_signup_subtitle_text_color',
            'customer_signup_main_btn_bg',
            'customer_signup_main_btn_text',
            'customer_signup_main_btn_glow',
            'customer_signup_main_btn_border_radius',
            'customer_signup_main_btn_shadow',
            'customer_signup_main_btn_animation',
            'provider_login_bg_color',
            'provider_login_bg_image_url',
            'provider_login_logo_url',
            'provider_login_header_color',
            'provider_login_header_opacity',
            'provider_login_heading',
            'provider_login_subtitle',
            'provider_login_heading_text_color',
            'provider_login_subtitle_text_color',
            'provider_login_main_btn_bg',
            'provider_login_main_btn_text',
            'provider_login_main_btn_glow',
            'provider_login_main_btn_border_radius',
            'provider_login_main_btn_shadow',
            'provider_login_main_btn_animation',
            'provider_signup_bg_color',
            'provider_signup_bg_image_url',
            'provider_signup_logo_url',
            'provider_signup_header_color',
            'provider_signup_header_opacity',
            'provider_signup_heading',
            'provider_signup_subtitle',
            'provider_signup_heading_text_color',
            'provider_signup_subtitle_text_color',
            'provider_signup_main_btn_bg',
            'provider_signup_main_btn_text',
            'provider_signup_main_btn_glow',
            'provider_signup_main_btn_border_radius',
            'provider_signup_main_btn_shadow',
            'provider_signup_main_btn_animation',
          ]);

      for (final row in response) {
        final key = row['setting_key'] as String;
        final value = row['setting_value'] as String;
        _applySetting(key, value);
      }
      
      // Start listening for real-time changes
      _subscribeToChanges();
      
      notifyListeners();
    } catch (_) {}
  }

  void _subscribeToChanges() {
    Supabase.instance.client
        .channel('public:app_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_settings',
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData.isNotEmpty) {
              final key = newData['setting_key'] as String;
              final val = newData['setting_value'] as String;
              _applySetting(key, val);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void _applySetting(String key, String value) {
    if (key == 'app_name' && value.isNotEmpty) _appName = value;
    if (key == 'app_tagline' && value.isNotEmpty) _appTagline = value;
    if (key == 'logo_url') _logoUrl = value;
    if (key == 'bg_image_url') _bgImageUrl = value;

    if (key == 'bg_color') {
      final color = _parseHexColor(value);
      if (color != null) _bgColor = color;
    }

    if (key == 'app_name_translations' && value.isNotEmpty) {
      try {
        final decoded = json.decode(value) as Map<String, dynamic>;
        _appNameTranslations = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    if (key == 'app_tagline_translations' && value.isNotEmpty) {
      try {
        final decoded = json.decode(value) as Map<String, dynamic>;
        _appTaglineTranslations = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    final color = _parseHexColor(value);
    if (color != null) {
      if (key == 'primary_color') _primaryColor = color;
      if (key == 'secondary_color') _secondaryColor = color;
    }

    // Provider main screen settings
    if (key == 'provider_main_screen_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainScreenBg = c;
    }
    if (key == 'provider_main_screen_bg_opacity') {
      final v = double.tryParse(value);
      if (v != null) _providerMainScreenBgOpacity = v;
    }
    if (key == 'provider_main_screen_bg_image_url') {
      _providerMainScreenBgImageUrl = value;
    }
    if (key == 'provider_main_header_opacity') {
      final v = double.tryParse(value);
      if (v != null) _providerMainHeaderOpacity = v;
    }
    if (key == 'provider_main_header_gradient_start') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainHeaderGradientStart = c;
    }
    if (key == 'provider_main_header_gradient_end') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainHeaderGradientEnd = c;
    }
    if (key == 'provider_main_header_text_color') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainHeaderTextColor = c;
    }
    if (key == 'provider_main_available_color') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainAvailableColor = c;
    }
    if (key == 'provider_main_unavailable_color') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainUnavailableColor = c;
    }
    if (key == 'provider_main_header_icon_btn_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainHeaderIconBtnBg = c;
    }
    if (key == 'provider_main_header_icon_btn_icon') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainHeaderIconBtnIcon = c;
    }
    if (key == 'provider_main_card_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainCardBg = c;
    }
    if (key == 'provider_main_card_border') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainCardBorder = c;
    }
    if (key == 'provider_main_urgent_border') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainUrgentBorder = c;
    }
    if (key == 'provider_main_action_btn_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainActionBtnBg = c;
    }
    if (key == 'provider_main_action_btn_text') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainActionBtnText = c;
    }
    if (key == 'provider_main_secondary_action_btn_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainSecondaryActionBtnBg = c;
    }
    if (key == 'provider_main_tab_selected_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainTabSelectedBg = c;
    }
    if (key == 'provider_main_tab_unselected_bg') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainTabUnselectedBg = c;
    }
    if (key == 'provider_main_tab_selected_text') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainTabSelectedText = c;
    }
    if (key == 'provider_main_tab_unselected_text') {
      final c = _parseHexColor(value);
      if (c != null) _providerMainTabUnselectedText = c;
    }

    // Login/signup role-specific settings (store raw values)
    if (key.contains('_login_') || key.contains('_signup_')) {
      _loginScreenSettings[key] = value;
    }
  }

  void updateSettings({
    Color? primary,
    Color? secondary,
    String? name,
    String? tagline,
    String? logo,
    Color? bgColor,
    String? bgImageUrl,
    Map<String, String>? appNameTranslations,
    Map<String, String>? appTaglineTranslations,
  }) {
    if (primary != null) _primaryColor = primary;
    if (secondary != null) _secondaryColor = secondary;
    if (name != null) _appName = name;
    if (tagline != null) _appTagline = tagline;
    if (logo != null) _logoUrl = logo;
    if (bgColor != null) _bgColor = bgColor;
    if (bgImageUrl != null) _bgImageUrl = bgImageUrl;
    if (appNameTranslations != null) _appNameTranslations = appNameTranslations;
    if (appTaglineTranslations != null) _appTaglineTranslations = appTaglineTranslations;
    notifyListeners();
  }

  Color? _parseHexColor(String hex) {
    try {
      if (!hex.startsWith('#')) return null;
      final buffer = StringBuffer();
      if (hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
