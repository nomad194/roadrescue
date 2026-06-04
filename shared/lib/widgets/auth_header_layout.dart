import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AuthHeaderLayout extends StatelessWidget {
  final String logoUrl;
  final Color headerColor;
  final double headerOpacity;
  final String appName;
  final String subtitle;
  final double animationValue;
  final Color headingTextColor;
  final Color subtitleTextColor;

  const AuthHeaderLayout({
    super.key,
    required this.logoUrl,
    required this.headerColor,
    required this.headerOpacity,
    required this.appName,
    required this.subtitle,
    required this.animationValue,
    required this.headingTextColor,
    required this.subtitleTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: animationValue,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: headerColor.withAlpha((255 * headerOpacity).round()),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: logoUrl,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (logoUrl.isNotEmpty) const SizedBox(height: 16),
            Text(
              appName,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: headingTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: subtitleTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
