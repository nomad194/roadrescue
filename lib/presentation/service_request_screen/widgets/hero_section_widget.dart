import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'dart:convert';

class HeroSectionWidget extends StatefulWidget {
  final String? cityName;
  final String? greeting;
  final String? userName;
  final String? locationAddress;
  final int? etaMinutes;
  final VoidCallback? onRefreshLocation;
  final VoidCallback? onNotificationTap;

  const HeroSectionWidget({
    super.key,
    this.cityName,
    this.greeting,
    this.userName,
    this.locationAddress,
    this.etaMinutes,
    this.onRefreshLocation,
    this.onNotificationTap,
  });

  @override
  State<HeroSectionWidget> createState() => _HeroSectionWidgetState();
}

class _HeroSectionWidgetState extends State<HeroSectionWidget> {
  Map<String, String> _headingTranslations = {};
  Map<String, String> _subtitleTranslations = {};
  Map<String, String> _labelTranslations = {};
  String _imageUrl = '';
  Color _headingTextColor = AppTheme.onSurface;
  Color _subtitleTextColor = AppTheme.onSurfaceVariant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeroSettings();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) _loadHeroSettings();
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadHeroSettings() async {
    try {
      final settings = await SupabaseService.instance.getAppSettings([
        'hero_heading',
        'hero_subtitle',
        'hero_label',
        'hero_image_url',
        'hero_heading_text_color',
        'hero_subtitle_text_color',
      ]);

      if (!mounted) return;

      setState(() {
        _headingTranslations = _parseTranslations(settings['hero_heading']);
        _subtitleTranslations = _parseTranslations(settings['hero_subtitle']);
        _labelTranslations = _parseTranslations(settings['hero_label']);
        _imageUrl = settings['hero_image_url'] ?? '';
        _headingTextColor = _parseColor(settings['hero_heading_text_color'], AppTheme.onSurface);
        _subtitleTextColor = _parseColor(settings['hero_subtitle_text_color'], AppTheme.onSurfaceVariant);
        _isLoading = false;
      });
      // Pre-cache the logo image
      final logoUrl = ThemeService.instance.logoUrl;
      if (logoUrl.isNotEmpty && mounted) {
        precacheImage(NetworkImage(logoUrl), context);
      }
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
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    final l = LocalizationService.instance;
    final ts = ThemeService.instance;
    final heading = _getText(_headingTranslations, '');
    final subtitle = _getText(_subtitleTranslations, '');
    final label = _getText(_labelTranslations, '');

    final greetingColor = ts.greetingTextColor;
    final userNameColor = ts.userNameTextColor;

    // Determine the logo/image URL
    final logoUrl = _imageUrl.isNotEmpty ? _imageUrl : ts.logoUrl;

    final bannerBg = ts.heroBgColor.withAlpha((255 * ts.heroBgOpacity).round());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Location + Greeting + Notification
                    Padding(
                      padding: const EdgeInsets.only(left: 90),
                      child: Row(
                        children: [
                          // Location
                          Flexible(
                            child: GestureDetector(
                              onTap: widget.onRefreshLocation,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      widget.cityName ?? l.t('location_not_set'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Greeting + Name
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('👋', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Hola${widget.userName != null && widget.userName!.isNotEmpty ? ', ' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: greetingColor,
                                    ),
                                  ),
                                ),
                                if (widget.userName != null && widget.userName!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      widget.userName!.split(' ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: userNameColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Notification bell
                          if (widget.onNotificationTap != null)
                            GestureDetector(
                              onTap: widget.onNotificationTap,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '3',
                                          style: GoogleFonts.manrope(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Full-width divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        height: 0.5,
                        color: ts.heroDividerColor.withAlpha((255 * ts.heroDividerOpacity).round()),
                      ),
                    ),
                    // Row 2: Street address + ETA
                    Padding(
                      padding: const EdgeInsets.only(left: 90),
                      child: Row(
                        children: [
                          // Street address
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.locationAddress ?? l.t('location_not_set'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ETA (only when active request has eta)
                          if (widget.etaMinutes != null) ...[
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ETA: ',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${widget.etaMinutes} min',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Optional: Heading / Subtitle / Label from admin
                    if (heading.isNotEmpty || subtitle.isNotEmpty || label.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (heading.isNotEmpty)
                              Text(
                                heading,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _headingTextColor,
                                ),
                              ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: _subtitleTextColor,
                                ),
                              ),
                            ],
                            if (label.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Logo/Image positioned on the left, can overflow the container
          Positioned(
            left: -20,
            top: -22,
            child: SizedBox(
              width: 150,
              height: 150,
              child: logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                    )
                  : _buildFallbackLogo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: 90,
      height: 90,
      alignment: Alignment.center,
      child: Icon(
        Icons.shield_rounded,
        size: 50,
        color: Colors.white.withAlpha(60),
      ),
    );
  }
}
