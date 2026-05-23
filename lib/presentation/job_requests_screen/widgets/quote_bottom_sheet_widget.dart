import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../services/supabase_service.dart';

class QuoteBottomSheetWidget extends StatefulWidget {
  final dynamic job;
  final Function(double price, int eta, String paymentMethods) onQuoteSubmitted;

  const QuoteBottomSheetWidget({
    super.key,
    required this.job,
    required this.onQuoteSubmitted,
  });

  @override
  State<QuoteBottomSheetWidget> createState() => _QuoteBottomSheetWidgetState();
}

class _QuoteBottomSheetWidgetState extends State<QuoteBottomSheetWidget> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _etaController = TextEditingController();
  final _noteController = TextEditingController();
  bool _offerCash = false;
  bool _offerOnline = false;
  bool _isSubmitting = false;
  bool _isLoadingMethods = true;
  bool _cashEnabledGlobally = false;
  bool _onlineEnabledGlobally = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.job.estimatedValue.toStringAsFixed(0);
    _etaController.text = '20';
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await SupabaseService.instance.getPaymentMethods();
      if (mounted) {
        setState(() {
          _cashEnabledGlobally = methods.any((m) => m['code'] == 'cash' && m['is_enabled'] == true);
          _onlineEnabledGlobally = methods.any((m) => m['code'] == 'stripe' && m['is_enabled'] == true);
          // Default to offering if globally enabled
          _offerCash = _cashEnabledGlobally;
          _offerOnline = _onlineEnabledGlobally;
          _isLoadingMethods = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          // Fallback to enabled if can't load
          _cashEnabledGlobally = true;
          _onlineEnabledGlobally = true;
          _offerCash = true;
          _offerOnline = true;
          _isLoadingMethods = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _etaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final price = double.tryParse(_priceController.text) ?? 0;
      final eta = int.tryParse(_etaController.text) ?? 20;
      final List<String> methods = [];
      if (_offerCash) methods.add('cash');
      if (_offerOnline) methods.add('online');
      final paymentMethods = methods.isEmpty ? 'cash' : methods.join(',');
      widget.onQuoteSubmitted(price, eta, paymentMethods);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('send_quote'),
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            '${widget.job.serviceType} · ${widget.job.id}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 15,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.job.driverName,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.job.distanceMiles} miles away',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('${l.t('your_price')} (\$)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.success,
                            ),
                            decoration: InputDecoration(
                              prefixText: '\$ ',
                              filled: true,
                              fillColor: AppTheme.successContainer,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(l.t('eta_minutes')),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _etaController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                            decoration: InputDecoration(
                              suffixText: ' min',
                              filled: true,
                              fillColor: AppTheme.primaryContainer,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldLabel(l.t('note_to_driver')),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'e.g. I have a flatbed truck...',
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel(l.t('payment_methods_offered')),
                const SizedBox(height: 8),
                if (_isLoadingMethods)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (!_cashEnabledGlobally && !_onlineEnabledGlobally)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.error.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No payment methods are currently enabled. Contact admin.',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      if (_cashEnabledGlobally)
                        _PaymentToggle(
                          label: l.t('cash'),
                          icon: Icons.payments_outlined,
                          isEnabled: _offerCash,
                          onChanged: (v) => setState(() => _offerCash = v),
                        ),
                      if (_cashEnabledGlobally && _onlineEnabledGlobally)
                        const SizedBox(width: 10),
                      if (_onlineEnabledGlobally)
                        _PaymentToggle(
                          label: l.t('online'),
                          icon: Icons.credit_card_outlined,
                          isEnabled: _offerOnline,
                          onChanged: (v) => setState(() => _offerOnline = v),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                l.t('submit_quote_to_driver'),
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _PaymentToggle({
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(!isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.primaryContainer
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled ? AppTheme.primary : AppTheme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isEnabled ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? AppTheme.primary : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
