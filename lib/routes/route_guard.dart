import 'package:flutter/material.dart';

import 'package:roadrescue_shared/services/supabase_service.dart';
import 'app_routes.dart';

/// Roles allowed per route. Null means any authenticated user (or public).
/// roadrescue is customer-only — provider routes have moved to provider_app.
const Map<String, List<String>?> _routeRoles = {
  AppRoutes.initial: null,
  AppRoutes.signUpLoginScreen: null,
  AppRoutes.faqTosScreen: null,
  AppRoutes.forgotPasswordScreen: null,
  AppRoutes.completeCustomerProfileScreen: ['customer'],
  AppRoutes.serviceRequestScreen: ['customer'],
  AppRoutes.customerProfileScreen: ['customer'],
  AppRoutes.serviceHistoryScreen: ['customer'],
  AppRoutes.myVehicleScreen: ['customer'],
  AppRoutes.paymentScreen: ['customer'],
  AppRoutes.postPaymentScreen: ['customer'],
  AppRoutes.phoneVerificationScreen: ['customer'],
};

/// Routes that require phone verification.
const Set<String> _phoneVerificationRequired = {
  AppRoutes.serviceRequestScreen,
  AppRoutes.customerProfileScreen,
  AppRoutes.paymentScreen,
  AppRoutes.postPaymentScreen,
  AppRoutes.serviceHistoryScreen,
  AppRoutes.myVehicleScreen,
};

class RouteGuard extends StatefulWidget {
  final String routeName;
  final Widget child;

  const RouteGuard({
    super.key,
    required this.routeName,
    required this.child,
  });

  static bool isPublicRoute(String routeName) {
    final allowed = _routeRoles[routeName];
    return allowed == null;
  }

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  // Cache the future so rebuilds don't re-fire it
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.instance.currentUser;
    if (user != null && _routeRoles[widget.routeName] != null) {
      _profileFuture = SupabaseService.instance.getUserProfile(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final allowedRoles = _routeRoles[widget.routeName];

    if (allowedRoles == null) {
      return widget.child;
    }

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.signUpLoginScreen,
          (r) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data?['role'] as String? ??
            user.userMetadata?['role'] as String? ??
            'customer';

        if (!allowedRoles.contains(role)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.serviceRequestScreen,
              (r) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Block users without phone verification from sensitive routes
        if (_phoneVerificationRequired.contains(widget.routeName)) {
          final phoneVerifiedAt = snapshot.data?['phone_verified_at'];
          if (phoneVerifiedAt == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.phoneVerificationScreen,
                (r) => false,
              );
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        }

        return widget.child;
      },
    );
  }
}
