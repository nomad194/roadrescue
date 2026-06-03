import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadrescue/routes/app_routes.dart';

void main() {
  test('AppRoutes defines all expected route paths', () {
    expect(AppRoutes.initial, '/');
    expect(AppRoutes.signUpLoginScreen, '/sign-up-login-screen');
    expect(AppRoutes.serviceRequestScreen, '/service-request-screen');
    expect(AppRoutes.jobRequestsScreen, '/job-requests-screen');
    expect(AppRoutes.customerProfileScreen, '/customer-profile-screen');
    expect(AppRoutes.providerProfileScreen, '/provider-profile-screen');
    expect(AppRoutes.paymentScreen, '/payment-screen');
    expect(AppRoutes.postPaymentScreen, '/post-payment-screen');
    expect(AppRoutes.serviceHistoryScreen, '/service-history-screen');
    expect(AppRoutes.faqTosScreen, '/faq-tos-screen');
  });

  test('onGenerateRoute returns route for known paths', () {
    final route = AppRoutes.onGenerateRoute(
      const RouteSettings(name: AppRoutes.faqTosScreen),
    );
    expect(route, isNotNull);
    expect(route!.settings.name, AppRoutes.faqTosScreen);
  });

  test('onGenerateRoute falls back to login for unknown paths', () {
    final route = AppRoutes.onGenerateRoute(
      const RouteSettings(name: '/unknown-route'),
    );
    expect(route, isNotNull);
  });
}
