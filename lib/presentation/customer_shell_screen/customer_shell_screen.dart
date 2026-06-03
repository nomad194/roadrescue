import 'package:flutter/material.dart';
import '../service_request_screen/service_request_screen.dart';
import '../service_request_screen/widgets/custom_bottom_nav_bar.dart';
import '../active_requests_screen/active_requests_screen.dart';
import '../service_history_screen/service_history_screen.dart';
import '../customer_profile_screen/customer_profile_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  final int initialIndex;

  const CustomerShellScreen({super.key, this.initialIndex = 0});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    ServiceRequestScreen(),
    ActiveRequestsScreen(),
    ServiceHistoryScreen(),
    CustomerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      floatingActionButton: const ChatFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
