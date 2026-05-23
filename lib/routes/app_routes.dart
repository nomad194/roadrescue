import 'package:flutter/material.dart';

import '../presentation/job_requests_screen/job_requests_screen.dart';
import '../presentation/service_request_screen/service_request_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/admin_dashboard_screen/admin_dashboard_screen.dart';
import '../presentation/customer_profile_screen/customer_profile_screen.dart';
import '../presentation/provider_profile_screen/provider_profile_screen.dart';
import '../presentation/payment_screen/payment_screen.dart';
import '../presentation/post_payment_screen/post_payment_screen.dart';
import '../presentation/service_history_screen/service_history_screen.dart';
import '../presentation/faq_tos_screen/faq_tos_screen.dart';
import '../presentation/provider_reviews_screen/provider_reviews_screen.dart';
import 'route_guard.dart';

class AppRoutes {
  static const String initial = '/';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String serviceRequestScreen = '/service-request-screen';
  static const String jobRequestsScreen = '/job-requests-screen';
  static const String adminDashboardScreen = '/admin-dashboard-screen';
  static const String customerProfileScreen = '/customer-profile-screen';
  static const String providerProfileScreen = '/provider-profile-screen';
  static const String paymentScreen = '/payment-screen';
  static const String postPaymentScreen = '/post-payment-screen';
  static const String serviceHistoryScreen = '/service-history-screen';
  static const String faqTosScreen = '/faq-tos-screen';
  static const String providerReviewsScreen = '/provider-reviews-screen';

  static final Map<String, WidgetBuilder> _builders = {
    initial: (context) => const SignUpLoginScreen(),
    signUpLoginScreen: (context) => const SignUpLoginScreen(),
    serviceRequestScreen: (context) => const ServiceRequestScreen(),
    jobRequestsScreen: (context) {
      final settings = ModalRoute.of(context)?.settings;
      final args = settings?.arguments;
      int initialTab = 0;
      if (args is Map<String, dynamic>) {
        initialTab = args['initialTabIndex'] as int? ?? 0;
      }
      return JobRequestsScreen(initialTabIndex: initialTab);
    },
    adminDashboardScreen: (context) => const AdminDashboardScreen(),
    customerProfileScreen: (context) => const CustomerProfileScreen(),
    providerProfileScreen: (context) => const ProviderProfileScreen(),
    paymentScreen: (context) => const PaymentScreen(),
    postPaymentScreen: (context) => const PostPaymentScreen(),
    serviceHistoryScreen: (context) => const ServiceHistoryScreen(),
    faqTosScreen: (context) => const FaqTosScreen(),
    providerReviewsScreen: (context) {
      final settings = ModalRoute.of(context)?.settings;
      final args = settings?.arguments;
      final providerId = args is Map<String, dynamic> ? args['providerId'] as String? : null;
      return ProviderReviewsScreen(providerId: providerId);
    },
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? initial;
    final builder = _builders[name];
    if (builder == null) {
      return MaterialPageRoute(
        builder: (context) => const SignUpLoginScreen(),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (context) => RouteGuard(
        routeName: name,
        child: builder(context),
      ),
    );
  }

  /// Legacy map for compatibility; prefer [onGenerateRoute].
  @Deprecated('Use onGenerateRoute with RouteGuard instead')
  static Map<String, WidgetBuilder> get routes => _builders;
}
