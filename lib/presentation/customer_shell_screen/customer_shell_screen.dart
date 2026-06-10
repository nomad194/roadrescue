import 'package:flutter/material.dart';
import '../service_request_screen/service_request_screen.dart';
import '../service_request_screen/widgets/custom_bottom_nav_bar.dart';
import '../active_requests_screen/active_requests_screen.dart';
import '../service_history_screen/service_history_screen.dart';
import '../customer_profile_screen/customer_profile_screen.dart';
import '../my_vehicle_screen/my_vehicle_screen.dart';
import '../faq_tos_screen/faq_tos_screen.dart';
import '../support_tickets_screen/support_tickets_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  final int initialIndex;

  const CustomerShellScreen({super.key, this.initialIndex = 0});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  late int _currentIndex;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    7,
    (_) => GlobalKey<NavigatorState>(),
  );

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      ServiceRequestScreen(
        onNavigateToActiveRequests: () => setState(() => _currentIndex = 1),
      ),
      const ActiveRequestsScreen(),
      const ServiceHistoryScreen(),
      CustomerProfileScreen(
        onNavigateToMyVehicle: () => setState(() => _currentIndex = 4),
        onNavigateToServiceHistory: () => setState(() => _currentIndex = 2),
        onNavigateToFAQ: () => setState(() => _currentIndex = 5),
        onNavigateToSupport: () => setState(() => _currentIndex = 6),
      ),
      const MyVehicleScreen(),
      const FaqTosScreen(),
      const SupportTicketsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      final navigator = _navigatorKeys[index].currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }

    // Pop any pushed routes on the current tab before switching away
    final currentNavigator = _navigatorKeys[_currentIndex].currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.popUntil((route) => route.isFirst);
    }

    // Ensure the target tab is also at its root before showing it
    final targetNavigator = _navigatorKeys[index].currentState;
    if (targetNavigator != null && targetNavigator.canPop()) {
      targetNavigator.popUntil((route) => route.isFirst);
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
        floatingActionButton: ChatFab(
          navigatorKey: _navigatorKeys[_currentIndex],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_screens.length, (index) {
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => _screens[index],
                  settings: settings,
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
