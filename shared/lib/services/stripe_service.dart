import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static Future<void> initialize() async {
    const publishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (publishableKey.isEmpty) return;
    if (!kIsWeb) {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
    }
  }
}
