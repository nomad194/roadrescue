import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'app_routes.dart';

/// Roles allowed per route. Null means any authenticated user.
const Map<String, List<String>?> _routeRoles = {
  AppRoutes.initial: null,
  AppRoutes.signUpLoginScreen: null,
  AppRoutes.faqTosScreen: null,
  AppRoutes.serviceRequestScreen: ['customer', 'provider', 'admin'],
  AppRoutes.customerProfileScreen: ['customer', 'provider', 'admin'],
  AppRoutes.serviceHistoryScreen: ['customer', 'provider', 'admin'],
  AppRoutes.paymentScreen: ['customer', 'provider', 'admin'],
  AppRoutes.postPaymentScreen: ['customer', 'provider', 'admin'],
  AppRoutes.jobRequestsScreen: ['customer', 'provider', 'admin'],
  AppRoutes.providerProfileScreen: ['customer', 'provider', 'admin'],
  AppRoutes.providerDocumentsScreen: ['provider', 'admin'],
  AppRoutes.adminDashboardScreen: ['admin'],
};

/// Routes that require document verification for providers.
/// If a provider is not verified, they will be redirected to the documents screen.
const Set<String> _providerVerificationRequired = {
  AppRoutes.jobRequestsScreen,
  AppRoutes.providerProfileScreen,
};

/// Routes that require phone verification.
/// All sensitive routes require phone verification.
const Set<String> _phoneVerificationRequired = {
  AppRoutes.serviceRequestScreen,
  AppRoutes.jobRequestsScreen,
  AppRoutes.customerProfileScreen,
  AppRoutes.providerProfileScreen,
  AppRoutes.paymentScreen,
  AppRoutes.postPaymentScreen,
  AppRoutes.serviceHistoryScreen,
  AppRoutes.providerDocumentsScreen,
  AppRoutes.adminDashboardScreen,
  AppRoutes.providerReviewsScreen,
};

class RouteGuard extends StatelessWidget {
  final String routeName;
  final Widget child;

  const RouteGuard({
    super.key,
    required this.routeName,
    required this.child,
  });

  static bool isPublicRoute(String routeName) {
    final allowed = _routeRoles[routeName];
    return allowed == null && routeName != AppRoutes.adminDashboardScreen;
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final allowedRoles = _routeRoles[routeName];

    if (allowedRoles == null) {
      return child;
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
      future: SupabaseService.instance.getUserProfile(user.id),
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
            final redirect = role == 'admin'
                ? AppRoutes.adminDashboardScreen
                : role == 'provider'
                    ? AppRoutes.jobRequestsScreen
                    : AppRoutes.serviceRequestScreen;
            Navigator.pushNamedAndRemoveUntil(context, redirect, (r) => false);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Block unverified providers from protected routes
        if (role == 'provider' &&
            _providerVerificationRequired.contains(routeName)) {
          final isVerified = snapshot.data?['is_verified'] as bool? ?? false;
          if (!isVerified) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.providerDocumentsScreen,
                (r) => false,
              );
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        }

        // Block users without phone verification from sensitive routes
        // Admins are exempt from phone verification
        if (_phoneVerificationRequired.contains(routeName) && role != 'admin') {
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

        return child;
      },
    );
  }
}
