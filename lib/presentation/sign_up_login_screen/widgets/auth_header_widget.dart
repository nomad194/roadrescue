import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/localization_service.dart';

class AuthHeaderWidget extends StatefulWidget {
  final bool isLogin;

  const AuthHeaderWidget({super.key, required this.isLogin});

  @override
  State<AuthHeaderWidget> createState() => _AuthHeaderWidgetState();
}

class _AuthHeaderWidgetState extends State<AuthHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56DB), Color(0xFF1E40AF), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(77),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _opacityAnimation,
            child: Text(
              LocalizationService.instance.t('app_name'),
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _opacityAnimation,
            child: Text(
              widget.isLogin
                  ? LocalizationService.instance.t('welcome_back_subtitle')
                  : LocalizationService.instance.t('join_subtitle'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.white.withAlpha(204),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
