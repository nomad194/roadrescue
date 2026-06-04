import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/localization_service.dart';
import '../theme/app_theme.dart';

class LanguageSelectorWidget extends StatelessWidget {
  final bool showAsDialog;
  const LanguageSelectorWidget({super.key, this.showAsDialog = false});

  static void showLanguageDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _LanguageDialog());
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final currentLang = l.currentLanguageCode;
    final langName =
        LocalizationService.supportedLanguages[currentLang] ?? 'English';

    return GestureDetector(
      onTap: () => showLanguageDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              langName,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDialog extends StatefulWidget {
  const _LanguageDialog();

  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  String _selected = LocalizationService.instance.currentLanguageCode;

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.language, color: AppTheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            l.t('select_language'),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: LocalizationService.supportedLanguages.entries.map((entry) {
            final isSelected = _selected == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _selected = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryContainer
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _flagEmoji(entry.key),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l.t('cancel'),
            style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            await LocalizationService.instance.setLanguage(_selected);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LocalizationService.instance.t('language_changed'),
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
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            l.t('save'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
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
}
