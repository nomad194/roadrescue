import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/services/chat_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/widgets/chat_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    onTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final ts = ThemeService.instance;
        final List<BoxShadow> navGlowShadows = ts.bottomNavGlowEnabled
            ? [
                BoxShadow(
                  color: ts.bottomNavOutlineColor.withAlpha((90 * ts.bottomNavGlowStrength).round().clamp(0, 255)),
                  blurRadius: 16 * ts.bottomNavGlowStrength,
                  spreadRadius: 4 * ts.bottomNavGlowStrength,
                ),
                BoxShadow(
                  color: ts.bottomNavOutlineColor.withAlpha((50 * ts.bottomNavGlowStrength).round().clamp(0, 255)),
                  blurRadius: 32 * ts.bottomNavGlowStrength,
                  spreadRadius: 8 * ts.bottomNavGlowStrength,
                ),
              ]
            : [];

        return Container(
          decoration: BoxDecoration(
            boxShadow: navGlowShadows,
          ),
          child: BottomAppBar(
            height: 70,
            padding: EdgeInsets.zero,
            elevation: 2,
            shadowColor: ts.bottomNavOutlineColor,
            color: ts.bottomNavBgColor,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: Row(
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: l.t('home'),
                  isActive: currentIndex == 0,
                  onTap: () => _onItemTapped(context, 0),
                  ts: ts,
                ),
                _buildNavItem(
                  icon: Icons.local_activity_rounded,
                  label: l.t('active_requests'),
                  isActive: currentIndex == 1,
                  onTap: () => _onItemTapped(context, 1),
                  ts: ts,
                ),
                // Spacer for FAB
                const SizedBox(width: 64),
                _buildNavItem(
                  icon: Icons.history_rounded,
                  label: l.t('history'),
                  isActive: currentIndex == 2,
                  onTap: () => _onItemTapped(context, 2),
                  ts: ts,
                ),
                _buildNavItem(
                  icon: Icons.person_rounded,
                  label: l.t('profile'),
                  isActive: currentIndex == 3,
                  onTap: () => _onItemTapped(context, 3),
                  ts: ts,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ThemeService ts,
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
              color: isActive ? ts.bottomNavActiveColor : ts.bottomNavInactiveColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? ts.bottomNavActiveColor : ts.bottomNavInactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatFab extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const ChatFab({super.key, this.navigatorKey});

  @override
  State<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<ChatFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _hasNewMessage = false;
  RealtimeChannel? _channel;
  List<String> _jobIds = [];
  Timer? _bounceTimer;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -14, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);

    _initSubscription();
  }

  Future<void> _initSubscription() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    // Fetch customer's active job IDs
    try {
      final response = await Supabase.instance.client
          .from('job_requests')
          .select('id')
          .eq('customer_id', userId)
          .inFilter('job_status', [
            'accepted',
            'confirmed',
            'en_route',
            'in_progress',
            'awaiting_confirmation',
            'awaiting_reconfirmation',
            'disputed',
            'completed',
          ]);
      final rows = response as List<dynamic>;
      _jobIds = rows.map((r) => r['id'].toString()).toList();
    } catch (_) {
      _jobIds = [];
    }

    if (_jobIds.isEmpty) return;

    _channel = ChatService.instance.subscribeToMessagesForJobs(
      _jobIds,
      (record) {
        final senderId = record['sender_id'] as String?;
        final currentUserId = SupabaseService.instance.currentUser?.id;
        final nav = widget.navigatorKey?.currentState;
        final isChatOpen = nav != null && nav.canPop();
        if (senderId != null && senderId != currentUserId && mounted && !isChatOpen) {
          setState(() => _hasNewMessage = true);
          _startBounceLoop();
        }
      },
    );
  }

  void _startBounceLoop() {
    _bounceTimer?.cancel();
    if (!_hasNewMessage) return;
    _bounceController.forward(from: 0);
    _bounceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_hasNewMessage && mounted) {
        _bounceController.forward(from: 0);
      }
    });
  }

  void _stopBounceLoop() {
    _bounceTimer?.cancel();
    _bounceTimer = null;
    _bounceController.stop();
    _bounceController.value = 0;
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    _channel?.unsubscribe();
    _bounceController.dispose();
    super.dispose();
  }

  bool get _isChatOpen {
    final nav = widget.navigatorKey?.currentState;
    return nav != null && nav.canPop();
  }

  void _onPressed(BuildContext context) {
    final nav = widget.navigatorKey?.currentState;
    if (nav != null && nav.canPop()) {
      // Chat is already open — close it and return to the tab's root
      nav.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _hasNewMessage = false);
    _stopBounceLoop();
    final Future<void> future;
    if (nav != null) {
      future = nav.push(
        MaterialPageRoute(
          builder: (_) => const ChatListScreen(roleFilter: 'customer'),
        ),
      );
    } else {
      future = Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ChatListScreen(roleFilter: 'customer'),
        ),
      );
    }
    future.whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final ts = ThemeService.instance;
        final List<BoxShadow> chatGlowShadows = ts.bottomNavChatGlowEnabled
            ? [
                BoxShadow(
                  color: ts.bottomNavChatOutlineColor.withAlpha((90 * ts.bottomNavChatGlowStrength).round().clamp(0, 255)),
                  blurRadius: 16 * ts.bottomNavChatGlowStrength,
                  spreadRadius: 4 * ts.bottomNavChatGlowStrength,
                ),
                BoxShadow(
                  color: ts.bottomNavChatOutlineColor.withAlpha((50 * ts.bottomNavChatGlowStrength).round().clamp(0, 255)),
                  blurRadius: 32 * ts.bottomNavChatGlowStrength,
                  spreadRadius: 8 * ts.bottomNavChatGlowStrength,
                ),
              ]
            : [];

        return AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ts.bottomNavChatOutlineColor, width: 2),
              boxShadow: chatGlowShadows,
            ),
            child: FloatingActionButton(
              onPressed: () => _onPressed(context),
              backgroundColor: ts.bottomNavChatBgColor,
              shape: const CircleBorder(),
              child: Icon(
                Icons.chat_rounded,
                color: _hasNewMessage
                    ? Colors.orange
                    : _isChatOpen
                        ? ts.bottomNavActiveColor
                        : ts.bottomNavChatIconColor,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}
