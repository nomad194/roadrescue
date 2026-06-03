import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/notification_service.dart';
import '../../routes/app_routes.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _clientSecret;
  String? _paymentIntentId;
  String? _recordId;
  double _commissionAmount = 0;
  double _providerPayout = 0;
  String? _error;

  late Map<String, dynamic> _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {};
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    final l = LocalizationService.instance;
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      final amount = (_args['amount'] as num?)?.toDouble() ?? 0.0;
      final bookingId = _args['bookingId'] as String?;
      final customerId = _args['customerId'] as String?;
      final providerId = _args['providerId'] as String?;

      if (amount <= 0) {
        setState(() {
          _error = l.t('invalid_amount');
          _isInitializing = false;
        });
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: {
          'bookingId': bookingId,
          'customerId': customerId,
          'providerId': providerId,
          'amount': amount,
          'currency': 'usd',
        },
      );

      if (response.data == null || response.data['error'] != null) {
        setState(() {
          _error = response.data?['error'] ?? l.t('payment_init_failed');
          _isInitializing = false;
        });
        return;
      }

      setState(() {
        _clientSecret = response.data['clientSecret'] as String;
        _paymentIntentId = response.data['paymentIntentId'] as String?;
        _recordId = response.data['recordId'] as String?;
        _commissionAmount =
            (response.data['commissionAmount'] as num?)?.toDouble() ?? 0;
        _providerPayout =
            (response.data['providerPayout'] as num?)?.toDouble() ?? 0;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _error = l.t('payment_init_failed');
        _isInitializing = false;
      });
    }
  }

  Future<void> _handlePayment() async {
    if (_clientSecret == null) return;
    setState(() => _isLoading = true);
    final l = LocalizationService.instance;

    try {
      if (kIsWeb) {
        // Web: use confirmPaymentElement
        await stripe.Stripe.instance.confirmPayment(
          paymentIntentClientSecret: _clientSecret!,
          data: const stripe.PaymentMethodParams.card(
            paymentMethodData: stripe.PaymentMethodData(),
          ),
        );
      } else {
        // Mobile: confirm with card details
        await stripe.Stripe.instance.confirmPayment(
          paymentIntentClientSecret: _clientSecret!,
          data: const stripe.PaymentMethodParams.card(
            paymentMethodData: stripe.PaymentMethodData(),
          ),
        );
      }

      // Confirm on backend
      if (_paymentIntentId != null) {
        await Supabase.instance.client.functions.invoke(
          'confirm-payment',
          body: {'paymentIntentId': _paymentIntentId},
        );
      }

      // Update job status to confirmed after successful payment
      final bookingId = _args['bookingId'] as String?;
      if (bookingId != null && bookingId.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('job_requests')
              .update({
                'job_status': 'confirmed',
                'payment_method_used': 'online',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', bookingId);
        } catch (_) {}
      }

      // Send notification to provider: quote accepted and paid
      final serviceType = _args['serviceType'] as String? ?? 'Service';
      await NotificationService.instance.notifyProviderQuoteAcceptedOnline(
        serviceType,
      );

      // Notify customer that payment was confirmed
      final amount = (_args['amount'] as num?)?.toDouble() ?? 0.0;
      await NotificationService.instance.notifyPaymentConfirmed(amount);

      if (mounted) {
        final showPostPayment =
            _args['showPostPaymentScreen'] as bool? ?? false;
        if (showPostPayment) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.postPaymentScreen,
            arguments: {
              'amount': amount,
              'bookingId': _args['bookingId'] ?? '',
              'serviceType': _args['serviceType'] ?? 'Roadside Service',
              'providerName': _args['providerName'] ?? '',
              'providerBusiness': _args['providerBusiness'] ?? '',
              'providerPhone': _args['providerPhone'] ?? '',
              'paymentMethod': 'Online (Stripe)',
              'customerName': _args['customerName'] ?? 'Customer',
            },
          );
        } else {
          Navigator.pop(context, {'success': true, 'recordId': _recordId});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l.t('payment_success'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } on stripe.StripeException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.error.localizedMessage ?? l.t('payment_failed'),
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('payment_failed'),
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final amount = (_args['amount'] as num?)?.toDouble() ?? 0.0;
    final serviceType = _args['serviceType'] as String? ?? 'Service';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppTheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.t('payment'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(l)
          : _buildPaymentForm(l, amount, serviceType),
    );
  }

  Widget _buildErrorState(LocalizationService l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              _error ?? l.t('error'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l.t('retry'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(
    LocalizationService l,
    double amount,
    String serviceType,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceType,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAmountRow(
                  l.t('total_amount'),
                  '\$${amount.toStringAsFixed(2)}',
                  isTotal: true,
                ),
                if (_commissionAmount > 0) ...[
                  const SizedBox(height: 6),
                  _buildAmountRow(
                    l.t('commission_fee'),
                    '-\$${_commissionAmount.toStringAsFixed(2)}',
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 6),
                  _buildAmountRow(
                    l.t('provider_receives'),
                    '\$${_providerPayout.toStringAsFixed(2)}',
                    color: AppTheme.success,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card input
          Text(
            l.t('card_information'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outline),
            ),
            child: stripe.CardField(
              onCardChanged: (card) {},
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: AppTheme.muted),
              const SizedBox(width: 4),
              Text(
                l.t('secure_payment'),
                style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pay button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l.t('processing'),
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${l.t('pay_now')} · \$${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color:
                color ??
                (isTotal ? AppTheme.onSurface : AppTheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
