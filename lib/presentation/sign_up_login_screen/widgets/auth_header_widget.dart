import 'package:flutter/material.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/widgets/auth_header_layout.dart';

class AuthHeaderWidget extends StatefulWidget {
  final bool isLogin;
  final String role;

  const AuthHeaderWidget({
    super.key,
    required this.isLogin,
    this.role = 'customer',
  });

  @override
  State<AuthHeaderWidget> createState() => _AuthHeaderWidgetState();
}

class _AuthHeaderWidgetState extends State<AuthHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance;
    final l = LocalizationService.instance;

    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return AuthHeaderLayout(
          logoUrl: themeService.getLogoFor(
            role: widget.role,
            isLogin: widget.isLogin,
          ),
          headerColor: themeService.getHeaderColorFor(
            role: widget.role,
            isLogin: widget.isLogin,
          ),
          headerOpacity: themeService.getHeaderOpacityFor(
            role: widget.role,
            isLogin: widget.isLogin,
          ),
          appName: themeService.getHeadingFor(role: widget.role, isLogin: widget.isLogin, languageCode: l.currentLanguageCode).isNotEmpty
              ? themeService.getHeadingFor(role: widget.role, isLogin: widget.isLogin, languageCode: l.currentLanguageCode)
              : (themeService.getLocalizedAppName(l.currentLanguageCode).isNotEmpty
                  ? themeService.getLocalizedAppName(l.currentLanguageCode)
                  : l.t('app_name')),
          subtitle: themeService.getSubtitleFor(role: widget.role, isLogin: widget.isLogin, languageCode: l.currentLanguageCode).isNotEmpty
              ? themeService.getSubtitleFor(role: widget.role, isLogin: widget.isLogin, languageCode: l.currentLanguageCode)
              : (widget.isLogin
                  ? l.t('welcome_back_subtitle')
                  : l.t('join_subtitle')),
          animationValue: _opacityAnimation.value,
          headingTextColor: themeService.getHeadingTextColorFor(role: widget.role, isLogin: widget.isLogin),
          subtitleTextColor: themeService.getSubtitleTextColorFor(role: widget.role, isLogin: widget.isLogin),
        );
      },
    );
  }
}
