import 'package:flutter/material.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/widgets/auth_header_layout.dart';

class AuthHeaderWidget extends StatelessWidget {
  final bool isLogin;
  final String role;

  const AuthHeaderWidget({
    super.key,
    required this.isLogin,
    this.role = 'customer',
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;
    final l = LocalizationService.instance;

    return AuthHeaderLayout(
      logoUrl: themeService.getLogoFor(
        role: role,
        isLogin: isLogin,
      ),
      headerColor: themeService.getHeaderColorFor(
        role: role,
        isLogin: isLogin,
      ),
      headerOpacity: themeService.getHeaderOpacityFor(
        role: role,
        isLogin: isLogin,
      ),
      appName: themeService.getHeadingFor(role: role, isLogin: isLogin, languageCode: l.currentLanguageCode).isNotEmpty
          ? themeService.getHeadingFor(role: role, isLogin: isLogin, languageCode: l.currentLanguageCode)
          : (themeService.getLocalizedAppName(l.currentLanguageCode).isNotEmpty
              ? themeService.getLocalizedAppName(l.currentLanguageCode)
              : l.t('app_name')),
      subtitle: themeService.getSubtitleFor(role: role, isLogin: isLogin, languageCode: l.currentLanguageCode).isNotEmpty
          ? themeService.getSubtitleFor(role: role, isLogin: isLogin, languageCode: l.currentLanguageCode)
          : (isLogin
              ? l.t('welcome_back_subtitle')
              : l.t('join_subtitle')),
      headingTextColor: themeService.getHeadingTextColorFor(role: role, isLogin: isLogin),
      subtitleTextColor: themeService.getSubtitleTextColorFor(role: role, isLogin: isLogin),
    );
  }
}
