import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'dart:convert';

class HeroSectionWidget extends StatefulWidget {
  const HeroSectionWidget({super.key});

  @override
  State<HeroSectionWidget> createState() => _HeroSectionWidgetState();
}

class _HeroSectionWidgetState extends State<HeroSectionWidget> {
  Map<String, String> _headingTranslations = {};
  Map<String, String> _subtitleTranslations = {};
  String _imageUrl = '';
  Color _bgColor = AppTheme.primary;
  double _bgOpacity = 0.04;
  Color _headingTextColor = AppTheme.onSurface;
  Color _subtitleTextColor = AppTheme.onSurfaceVariant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeroSettings();
  }

  Future<void> _loadHeroSettings() async {
    try {
      final settings = await SupabaseService.instance.getAppSettings([
        'hero_heading',
        'hero_subtitle',
        'hero_image_url',
        'hero_bg_color',
        'hero_bg_opacity',
        'hero_heading_text_color',
        'hero_subtitle_text_color',
      ]);

      if (!mounted) return;

      setState(() {
        _headingTranslations = _parseTranslations(settings['hero_heading']);
        _subtitleTranslations = _parseTranslations(settings['hero_subtitle']);
        _imageUrl = settings['hero_image_url'] ?? '';
        _bgColor = _parseColor(settings['hero_bg_color'], AppTheme.primary);
        _bgOpacity = double.tryParse(settings['hero_bg_opacity'] ?? '') ?? 0.04;
        _headingTextColor = _parseColor(settings['hero_heading_text_color'], AppTheme.onSurface);
        _subtitleTextColor = _parseColor(settings['hero_subtitle_text_color'], AppTheme.onSurfaceVariant);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, String> _parseTranslations(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {'en': raw};
    }
  }

  Color _parseColor(String? raw, Color fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      String hex = raw.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _getText(Map<String, String> translations, String fallback) {
    final l = LocalizationService.instance;
    final lang = l.currentLocale.languageCode;
    return translations[lang] ?? translations['en'] ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }

    final l = LocalizationService.instance;
    final heading = _getText(_headingTranslations, '');
    final subtitle = _getText(_subtitleTranslations, l.t('welcome_back_subtitle'));

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _bgColor.withAlpha((255 * _bgOpacity).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bgColor.withAlpha((255 * _bgOpacity * 4).round().clamp(0, 255))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                _imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (_imageUrl.isNotEmpty) const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _headingTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: _subtitleTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
