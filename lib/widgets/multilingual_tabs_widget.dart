import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';

/// A reusable widget that shows a tab per enabled language for entering translations.
/// Used in admin dialogs for categories, FAQ, subscription plans, Terms, Privacy, blog, etc.
class MultilingualTabsWidget extends StatefulWidget {
  /// The initial translations map: { 'en': 'text', 'es': 'texto', ... }
  final Map<String, String> initialTranslations;

  /// Label shown above each text field
  final String fieldLabel;

  /// Hint text inside each text field
  final String? hint;

  /// Max lines for the text field (1 for single-line, >1 for multiline)
  final int maxLines;

  /// Called whenever translations change
  final ValueChanged<Map<String, String>> onChanged;

  /// Called when the selected language tab changes, with the new language code
  final ValueChanged<String>? onTabChanged;

  /// Which languages to show tabs for (defaults to all enabled)
  final List<String>? enabledLanguages;

  const MultilingualTabsWidget({
    super.key,
    required this.initialTranslations,
    required this.fieldLabel,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.enabledLanguages,
    this.onTabChanged,
  });

  @override
  State<MultilingualTabsWidget> createState() => _MultilingualTabsWidgetState();
}

class _MultilingualTabsWidgetState extends State<MultilingualTabsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _langCodes;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _langCodes =
        widget.enabledLanguages ??
        LocalizationService.supportedLanguages.keys.toList();
    _controllers = {
      for (final code in _langCodes)
        code: TextEditingController(
          text: widget.initialTranslations[code] ?? '',
        ),
    };
    _tabController = TabController(length: _langCodes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged?.call(_langCodes[_tabController.index]);
      }
    });

    // Listen for changes and notify parent
    for (final entry in _controllers.entries) {
      entry.value.addListener(() {
        widget.onChanged({
          for (final e in _controllers.entries) e.key: e.value.text,
        });
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _flagEmoji(String code) {
    switch (code) {
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'pt':
        return '🇧🇷';
      case 'de':
        return '🇩🇪';
      case 'ar':
        return '🇸🇦';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Language tab bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(3),
            tabs: _langCodes.map((code) {
              final name =
                  LocalizationService.supportedLanguages[code] ??
                  code.toUpperCase();
              final hasContent = _controllers[code]?.text.isNotEmpty == true;
              return Tab(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _flagEmoji(code),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasContent) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        // Tab content
        SizedBox(
          height: widget.maxLines == 1 ? 72 : (widget.maxLines * 22.0 + 40),
          child: TabBarView(
            controller: _tabController,
            children: _langCodes.map((code) {
              final isDefault = code == l.defaultLanguage;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDefault)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${l.t('default_language')} — ${l.t('fallback_language')}',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controllers[code],
                      maxLines: widget.maxLines,
                      textDirection: code == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: widget.hint ?? l.t('enter_translation'),
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
                        fontSize: 13,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
