import 'package:flutter/material.dart';

import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/payment_screen/payment_screen.dart';
import '../presentation/post_payment_screen/post_payment_screen.dart';
import '../presentation/customer_shell_screen/customer_shell_screen.dart';
import '../presentation/faq_tos_screen/faq_tos_screen.dart';
import '../presentation/phone_verification_screen/phone_verification_screen.dart';
import '../presentation/complete_customer_profile_screen/complete_customer_profile_screen.dart';
import '../presentation/forgot_password_screen/forgot_password_screen.dart';
import '../presentation/my_vehicle_screen/my_vehicle_screen.dart';
import '../presentation/service_history_screen/service_history_screen.dart';
import '../presentation/support_tickets_screen/support_tickets_screen.dart';
import 'route_guard.dart';

class AppRoutes {
  static const String initial = '/';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String serviceRequestScreen = '/service-request-screen';
  static const String customerProfileScreen = '/customer-profile-screen';
  static const String paymentScreen = '/payment-screen';
  static const String postPaymentScreen = '/post-payment-screen';
  static const String serviceHistoryScreen = '/service-history-screen';
  static const String myVehicleScreen = '/my-vehicle';
  static const String faqTosScreen = '/faq-tos-screen';
  static const String phoneVerificationScreen = '/phone-verification-screen';
  static const String completeCustomerProfileScreen = '/complete-customer-profile';
  static const String forgotPasswordScreen = '/forgot-password';
  static const String supportTicketsScreen = '/support-tickets';

  static final Map<String, WidgetBuilder> _builders = {
    initial: (context) => const SignUpLoginScreen(),
    signUpLoginScreen: (context) => const SignUpLoginScreen(),
    serviceRequestScreen: (context) => const CustomerShellScreen(initialIndex: 0),
    customerProfileScreen: (context) => const CustomerShellScreen(initialIndex: 3),
    paymentScreen: (context) => const PaymentScreen(),
    postPaymentScreen: (context) => const PostPaymentScreen(),
    serviceHistoryScreen: (context) => const ServiceHistoryScreen(),
    myVehicleScreen: (context) => const MyVehicleScreen(),
    faqTosScreen: (context) => const FaqTosScreen(),
    phoneVerificationScreen: (context) => const PhoneVerificationScreen(),
    completeCustomerProfileScreen: (context) => const CompleteCustomerProfileScreen(),
    forgotPasswordScreen: (context) => const ForgotPasswordScreen(),
    supportTicketsScreen: (context) => const SupportTicketsScreen(),
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
