import 'package:flutter/material.dart';

import '../presentation/job_requests_screen/job_requests_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/provider_profile_screen/provider_profile_screen.dart';
import '../presentation/payment_screen/payment_screen.dart';
import '../presentation/post_payment_screen/post_payment_screen.dart';
import '../presentation/customer_shell_screen/customer_shell_screen.dart';
import '../presentation/faq_tos_screen/faq_tos_screen.dart';
import '../presentation/provider_documents_screen/provider_documents_screen.dart';
import '../presentation/provider_reviews_screen/provider_reviews_screen.dart';
import '../presentation/phone_verification_screen/phone_verification_screen.dart';
import '../presentation/provider_login_screen/provider_login_screen.dart';
import '../presentation/complete_customer_profile_screen/complete_customer_profile_screen.dart';
import '../presentation/complete_provider_profile_screen/complete_provider_profile_screen.dart';
import '../presentation/forgot_password_screen/forgot_password_screen.dart';
import 'route_guard.dart';

class AppRoutes {
  static const String initial = '/';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String serviceRequestScreen = '/service-request-screen';
  static const String jobRequestsScreen = '/job-requests-screen';
  static const String customerProfileScreen = '/customer-profile-screen';
  static const String providerProfileScreen = '/provider-profile-screen';
  static const String paymentScreen = '/payment-screen';
  static const String postPaymentScreen = '/post-payment-screen';
  static const String serviceHistoryScreen = '/service-history-screen';
  static const String faqTosScreen = '/faq-tos-screen';
  static const String providerReviewsScreen = '/provider-reviews-screen';
  static const String providerDocumentsScreen = '/provider-documents-screen';
  static const String phoneVerificationScreen = '/phone-verification-screen';
  static const String providerLoginScreen = '/provider-login-screen';
  static const String completeCustomerProfileScreen = '/complete-customer-profile';
  static const String completeProviderProfileScreen = '/complete-provider-profile';
  static const String forgotPasswordScreen = '/forgot-password';

  static final Map<String, WidgetBuilder> _builders = {
    initial: (context) => const SignUpLoginScreen(),
    signUpLoginScreen: (context) => const SignUpLoginScreen(),
    serviceRequestScreen: (context) => const CustomerShellScreen(initialIndex: 0),
    jobRequestsScreen: (context) {
      final settings = ModalRoute.of(context)?.settings;
      final args = settings?.arguments;
      int initialTab = 0;
      if (args is Map<String, dynamic>) {
        initialTab = args['initialTabIndex'] as int? ?? 0;
      }
      return JobRequestsScreen(initialTabIndex: initialTab);
    },
    customerProfileScreen: (context) => const CustomerShellScreen(initialIndex: 3),
    providerProfileScreen: (context) => const ProviderProfileScreen(),
    paymentScreen: (context) => const PaymentScreen(),
    postPaymentScreen: (context) => const PostPaymentScreen(),
    serviceHistoryScreen: (context) => const CustomerShellScreen(initialIndex: 1),
    faqTosScreen: (context) => const FaqTosScreen(),
    providerReviewsScreen: (context) {
      final settings = ModalRoute.of(context)?.settings;
      final args = settings?.arguments;
      final providerId = args is Map<String, dynamic> ? args['providerId'] as String? : null;
      return ProviderReviewsScreen(providerId: providerId);
    },
    providerDocumentsScreen: (context) => const ProviderDocumentsScreen(),
    phoneVerificationScreen: (context) => const PhoneVerificationScreen(),
    providerLoginScreen: (context) => const ProviderLoginScreen(),
    completeCustomerProfileScreen: (context) => const CompleteCustomerProfileScreen(),
    completeProviderProfileScreen: (context) => const CompleteProviderProfileScreen(),
    forgotPasswordScreen: (context) => const ForgotPasswordScreen(),
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

}
