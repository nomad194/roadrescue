import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import '../../../routes/app_routes.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const CustomBottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    onTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return BottomAppBar(
      height: 70,
      padding: EdgeInsets.zero,
      elevation: 16,
      shadowColor: Colors.black.withAlpha(60),
      color: AppTheme.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: l.t('home'),
            isActive: currentIndex == 0,
            onTap: () => _onItemTapped(context, 0),
          ),
          _buildNavItem(
            icon: Icons.local_activity_rounded,
            label: l.t('active_requests'),
            isActive: currentIndex == 1,
            onTap: () => _onItemTapped(context, 1),
          ),
          // Spacer for FAB
          const SizedBox(width: 64),
          _buildNavItem(
            icon: Icons.history_rounded,
            label: l.t('history'),
            isActive: currentIndex == 2,
            onTap: () => _onItemTapped(context, 2),
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: l.t('profile'),
            isActive: currentIndex == 3,
            onTap: () => _onItemTapped(context, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatFab extends StatelessWidget {
  const ChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        final nav = Navigator.of(context);
        showModalBottomSheet(
          context: nav.context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 32,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Coming Soon',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live chat support is on the way. For now, check our FAQ for help.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(nav.context, AppRoutes.faqTosScreen);
                      },
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: Text(LocalizationService.instance.t('faq')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      LocalizationService.instance.t('close'),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      backgroundColor: AppTheme.primary,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.chat_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
