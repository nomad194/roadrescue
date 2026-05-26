import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/localization_service.dart';

// Conditional imports for file download
import 'post_payment_download_stub.dart'
    if (dart.library.html) 'post_payment_download_web.dart'
    if (dart.library.io) 'post_payment_download_mobile.dart';

class PostPaymentScreen extends StatefulWidget {
  const PostPaymentScreen({super.key});

  @override
  State<PostPaymentScreen> createState() => _PostPaymentScreenState();
}

class _PostPaymentScreenState extends State<PostPaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isDownloading = false;

  Map<String, dynamic> _args = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _args = args;
    }
  }

  String get _bookingRef => (_args['bookingId'] as String? ?? 'N/A')
      .substring(0, (_args['bookingId'] as String? ?? 'N/A').length.clamp(0, 8))
      .toUpperCase();

  double get _amount => (_args['amount'] as num?)?.toDouble() ?? 0.0;
  String get _serviceType =>
      _args['serviceType'] as String? ?? 'Roadside Service';
  String get _providerName => _args['providerName'] as String? ?? 'Provider';
  String get _providerBusiness => _args['providerBusiness'] as String? ?? '';
  String get _providerPhone => _args['providerPhone'] as String? ?? '';
  String get _paymentMethod => _args['paymentMethod'] as String? ?? 'Online';
  String get _customerName => _args['customerName'] as String? ?? 'Customer';
  String get _invoiceNumber =>
      'INV-${DateTime.now().year}-${_bookingRef.isNotEmpty ? _bookingRef : '000000'}';
  String get _invoiceDate =>
      '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';

  Future<void> _downloadInvoice() async {
    final l = LocalizationService.instance;
    setState(() => _isDownloading = true);
    try {
      final invoiceContent = _buildInvoiceText();
      await downloadInvoiceFile(invoiceContent, '$_invoiceNumber.txt');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invoice downloaded successfully!',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('generic_error'),
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
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _buildInvoiceText() {
    final l = LocalizationService.instance;
    return '''
ROAD RESCUE - SERVICE INVOICE
==============================
${l.t('invoice')} Number : $_invoiceNumber
${l.t('invoice')} Date   : $_invoiceDate
${l.t('booking_ref')}    : #$_bookingRef
${l.t('payment')} Method : $_paymentMethod

${l.t('customer').toUpperCase()}
--------
Name: $_customerName

${l.t('service_provider').toUpperCase()}
----------------
Name    : $_providerName
Business: $_providerBusiness
Phone   : $_providerPhone

SERVICE DETAILS
---------------
${l.t('select_service')}   : $_serviceType
Amount Charged : \$${_amount.toStringAsFixed(2)}

PAYMENT SUMMARY
---------------
${l.t('subtotal')}       : \$${_amount.toStringAsFixed(2)}
${l.t('tax')} (0%)       : \$0.00
${l.t('total_amount')}     : \$${_amount.toStringAsFixed(2)}

==============================
Thank you for using Road Rescue!
For support, contact us through the app.
''';
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.serviceRequestScreen,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.onSurface),
          onPressed: _goHome,
        ),
        title: Text(
          l.t('payment_receipt'),
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildInvoiceText()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l.t('invoice_copied'),
                    style: GoogleFonts.manrope(fontSize: 13),
                  ),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Success animation
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.success.withAlpha(80),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.success,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Text(
                    l.t('payment_success'),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.t('booking_confirmed_info'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Invoice card
            FadeTransition(opacity: _fadeAnim, child: _buildInvoiceCard(l)),
            const SizedBox(height: 20),

            // Provider info card
            FadeTransition(opacity: _fadeAnim, child: _buildProviderCard(l)),
            const SizedBox(height: 28),

            // Download button
            FadeTransition(
              opacity: _fadeAnim,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _downloadInvoice,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isDownloading ? l.t('loading') : l.t('download_invoice'),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Back to home button
            FadeTransition(
              opacity: _fadeAnim,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: Text(
                    l.t('back_to_home'),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(LocalizationService l) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('invoice'),
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        _invoiceNumber,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.primary.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.success.withAlpha(80)),
                  ),
                  child: Text(
                    l.t('paid'),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(l.t('booking_ref'), '#$_bookingRef'),
                const Divider(color: AppTheme.outlineVariant, height: 20),
                _buildDetailRow('${l.t('invoice')} Date', _invoiceDate),
                const Divider(color: AppTheme.outlineVariant, height: 20),
                _buildDetailRow(l.t('select_service'), _serviceType),
                const Divider(color: AppTheme.outlineVariant, height: 20),
                _buildDetailRow('${l.t('payment')} Method', _paymentMethod),
                const Divider(color: AppTheme.outlineVariant, height: 20),
                _buildDetailRow(l.t('customer'), _customerName),
                const SizedBox(height: 16),

                // Amount section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.t('subtotal'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '\$${_amount.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.t('tax'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '\$0.00',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppTheme.outlineVariant, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.t('total_amount'),
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            '\$${_amount.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(LocalizationService l) {
    return Container(
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
            l.t('service_provider'),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryContainer,
                child: Text(
                  _providerName.isNotEmpty
                      ? _providerName[0].toUpperCase()
                      : 'P',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _providerName,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (_providerBusiness.isNotEmpty)
                      Text(
                        _providerBusiness,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    if (_providerPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _providerPhone,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.success,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
