import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

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
  bool _offerCash = true;
  bool _offerOnline = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with estimated value as suggestion
    _priceController.text = widget.job.estimatedValue.toStringAsFixed(0);
    _etaController.text = '20';
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
      // Build payment methods string from toggles
      final List<String> methods = [];
      if (_offerCash) methods.add('cash');
      if (_offerOnline) methods.add('online');
      final paymentMethods = methods.isEmpty ? 'cash' : methods.join(',');
      widget.onQuoteSubmitted(price, eta, paymentMethods);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l = LocalizationService.instance;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              // Header
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
              const SizedBox(height: 4),
              // Driver info chip
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
                      '${widget.job.distanceMiles} ${l.t('miles')} away',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Price + ETA row
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
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                            filled: true,
                            fillColor: AppTheme.successContainer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.success,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return l.t('required_field');
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) {
                              return '${l.t('error')}: valid price';
                            }
                            if (val > 9999) return '${l.t('max_limit')} \$9,999';
                            return null;
                          },
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
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            suffixText: ' min',
                            suffixStyle: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.muted,
                            ),
                            filled: true,
                            fillColor: AppTheme.primaryContainer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return l.t('required_field');
                            final val = int.tryParse(v);
                            if (val == null || val <= 0) {
                              return '${l.t('error')}: valid ETA';
                            }
                            if (val > 240) return '${l.t('max_limit')} 240 min';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Note to driver
              _buildFieldLabel(l.t('note_to_driver')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText:
                      'e.g. I have a flatbed truck, can accommodate your vehicle…',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  counterStyle: GoogleFonts.manrope(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Payment options
              _buildFieldLabel(l.t('payment_methods_offered')),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaymentToggle(
                    label: l.t('cash'),
                    icon: Icons.payments_outlined,
                    isEnabled: _offerCash,
                    onChanged: (v) => setState(() => _offerCash = v),
                  ),
                  const SizedBox(width: 10),
                  _PaymentToggle(
                    label: l.t('online'),
                    icon: Icons.credit_card_outlined,
                    isEnabled: _offerOnline,
                    onChanged: (v) => setState(() => _offerOnline = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
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
              width: isEnabled ? 1.5 : 1,
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
              const SizedBox(width: 6),
              if (isEnabled)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
