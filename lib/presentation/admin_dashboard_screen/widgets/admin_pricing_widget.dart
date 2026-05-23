import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

class AdminPricingWidget extends StatefulWidget {
  const AdminPricingWidget({super.key});

  @override
  State<AdminPricingWidget> createState() => _AdminPricingWidgetState();
}

class _AdminPricingWidgetState extends State<AdminPricingWidget> {
  bool _onlinePaymentEnabled = true;
  bool _cashPaymentEnabled = true;

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('pricing'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          'Manage surcharges, discounts, and payment options',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Payment Methods
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.t('payment')} Methods',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online ${l.t('payment')}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Cards, wallets & transfers',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _onlinePaymentEnabled,
                    onChanged: (v) => setState(() => _onlinePaymentEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
              const Divider(height: 20, color: AppTheme.outlineVariant),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash ${l.t('payment')}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Providers can accept cash',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _cashPaymentEnabled,
                    onChanged: (v) => setState(() => _cashPaymentEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
