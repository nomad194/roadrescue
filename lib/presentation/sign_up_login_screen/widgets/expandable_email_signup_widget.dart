import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

import 'auth_form_widget.dart';

class ExpandableEmailSignupWidget extends StatefulWidget {
  final bool isLoading;
  final String selectedRole;
  final Future<void> Function({
    required String email,
    required String password,
    String fullName,
    String phone,
  }) onSubmit;

  const ExpandableEmailSignupWidget({
    super.key,
    required this.isLoading,
    required this.selectedRole,
    required this.onSubmit,
  });

  @override
  State<ExpandableEmailSignupWidget> createState() =>
      _ExpandableEmailSignupWidgetState();
}

class _ExpandableEmailSignupWidgetState
    extends State<ExpandableEmailSignupWidget>
    with TickerProviderStateMixin {
  bool _isExpanded = false;

  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeOutCubic),
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _rotateController.forward();
    } else {
      _rotateController.reverse();
    }
  }

  List<BoxShadow> _resolveShadow(String shadow, Color glowColor) {
    if (shadow == 'none') return [];
    final alpha = switch (shadow) {
      'light' => 40,
      'heavy' => 120,
      _ => 80,
    };
    final blur = switch (shadow) {
      'light' => 8.0,
      'heavy' => 24.0,
      _ => 16.0,
    };
    final spread = switch (shadow) {
      'light' => 0.0,
      'heavy' => 2.0,
      _ => 1.0,
    };
    return [BoxShadow(color: glowColor.withAlpha(alpha), blurRadius: blur, spreadRadius: spread)];
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final themeService = ThemeService.instance;
    final bgColor = themeService.getMainButtonBgColorFor(role: widget.selectedRole, isLogin: false);
    final textColor = themeService.getMainButtonTextColorFor(role: widget.selectedRole, isLogin: false);
    final glowColor = themeService.getMainButtonGlowColorFor(role: widget.selectedRole, isLogin: false);
    final borderRadius = themeService.getMainButtonBorderRadiusFor(role: widget.selectedRole, isLogin: false);
    final shadow = themeService.getMainButtonShadowFor(role: widget.selectedRole, isLogin: false);
    final animation = themeService.getMainButtonAnimationFor(role: widget.selectedRole, isLogin: false);

    Widget button = ElevatedButton.icon(
      onPressed: widget.isLoading ? null : _toggleExpand,
      icon: Icon(Icons.email_outlined, color: textColor),
      label: Text(
        l.t('create_with_email'),
        style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        disabledBackgroundColor: bgColor.withAlpha(100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );

    button = Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: _resolveShadow(shadow, glowColor ?? bgColor),
      ),
      child: button,
    );

    if (animation == 'pulse') {
      button = AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = 1.0 + (_animController.value * 0.02);
          return Transform.scale(scale: scale, child: child);
        },
        child: button,
      );
    } else if (animation == 'fade') {
      button = AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final opacity = 0.9 + (_animController.value * 0.1);
          return Opacity(opacity: opacity, child: child);
        },
        child: button,
      );
    }

    return Column(
      children: [
        button,

        // Animated expanded form container
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: _isExpanded ? null : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: Visibility(
              visible: _isExpanded,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with collapse action
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.t('create_account'),
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _toggleExpand,
                            customBorder: const CircleBorder(),
                            child: AnimatedBuilder(
                              animation: _rotateAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotateAnimation.value * 3.14159,
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppTheme.muted,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Re-use existing auth form
                      AuthFormWidget(
                        isLogin: false,
                        isLoading: widget.isLoading,
                        selectedRole: widget.selectedRole,
                        onSubmit: widget.onSubmit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
