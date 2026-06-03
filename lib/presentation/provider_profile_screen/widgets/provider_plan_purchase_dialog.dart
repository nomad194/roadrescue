import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import '../../../routes/app_routes.dart';

class ProviderPlanPurchaseDialog extends StatefulWidget {
  final String? currentPlanId;
  
  const ProviderPlanPurchaseDialog({
    super.key,
    this.currentPlanId,
  });

  @override
  State<ProviderPlanPurchaseDialog> createState() => _ProviderPlanPurchaseDialogState();
}

class _ProviderPlanPurchaseDialogState extends State<ProviderPlanPurchaseDialog> {
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _selectedPlanId;
  String? _selectedPaymentMethod;
  File? _receiptFile;
  String _billingCycle = 'monthly';
  bool _documentsNotVerified = false;
  bool _showProviderPlanPricing = true;
  String _providerPlanManagementUrl = '';

  // Subscription state from provider_subscription_state
  bool _trialUsed = false;
  String? _trialPlanId;
  bool _trialResetAllowed = false;
  int _paidMonths = 0;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Check document verification first
      final providerId = SupabaseService.instance.currentUser?.id;
      if (providerId != null) {
        final verified = await SupabaseService.instance.isProviderDocumentsVerified(providerId);
        if (!verified) {
          if (mounted) {
            setState(() {
              _documentsNotVerified = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Load plan pricing visibility settings
      final showPricingSetting = await SupabaseService.instance.getAppSetting('show_provider_plan_pricing');
      final planUrlSetting = await SupabaseService.instance.getAppSetting('provider_plan_management_url');

      // Load plans
      final plansResponse = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price_monthly', ascending: true);

      // Load enabled payment methods
      final methods = await SupabaseService.instance.getProviderPaymentMethods();

      // Load subscription state (trial eligibility)
      Map<String, dynamic> subState = {};
      if (providerId != null) {
        subState = await SupabaseService.instance.getProviderSubscriptionState(providerId);
      }
      
      if (mounted) {
        setState(() {
          _showProviderPlanPricing = showPricingSetting != 'false';
          _providerPlanManagementUrl = planUrlSetting ?? '';
          _plans = List<Map<String, dynamic>>.from(plansResponse);
          _paymentMethods = methods;
          _trialUsed = subState['trial_used'] as bool? ?? false;
          _trialPlanId = subState['trial_plan_id'] as String?;
          _trialResetAllowed = subState['trial_reset_allowed'] as bool? ?? false;
          _paidMonths = (subState['paid_months'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked != null) {
      setState(() => _receiptFile = File(picked.path));
    }
  }

  Future<void> _purchasePlan() async {
    final l = LocalizationService.instance;
    if (_selectedPlanId == null) {
      _showError(l.t('please_select_plan'));
      return;
    }

    final plan = _plans.firstWhere((p) => p['id'] == _selectedPlanId);
    final priceMonthly = (plan['price_monthly'] as num?)?.toDouble() ?? 0.0;
    final priceYearly = (plan['price_yearly'] as num?)?.toDouble();
    final amount = _billingCycle == 'yearly' && priceYearly != null
        ? priceYearly
        : priceMonthly;
    final trialDays = (plan['trial_days'] as num?)?.toInt() ?? 0;
    final providerId = SupabaseService.instance.currentUser?.id;

    if (providerId == null) {
      _showError(l.t('not_logged_in'));
      return;
    }

    // Only require payment method if no trial period
    if (trialDays == 0 && _selectedPaymentMethod == null) {
      _showError(l.t('please_select_payment'));
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      // If trial period exists, route through Edge Function with eligibility check
      if (trialDays > 0) {
        // Check trial eligibility locally first for fast feedback
        if (_trialUsed && !_trialResetAllowed) {
          _showError(l.t('trial_already_used'));
          setState(() => _isPurchasing = false);
          return;
        }
        if (_trialUsed && _trialResetAllowed && _trialPlanId == _selectedPlanId) {
          _showError(l.t('trial_same_plan'));
          setState(() => _isPurchasing = false);
          return;
        }

        final result = await SupabaseService.instance.startProviderTrial(
          providerId: providerId,
          planId: _selectedPlanId!,
        );

        if (result['ok'] != true && result['success'] != true) {
          final errorKey = result['error']?.toString() ?? 'failed_start_trial';
          // Map DB error codes to localized strings
          String errorMsg;
          if (errorKey == 'trial_already_used') {
            errorMsg = l.t('trial_already_used');
          } else if (errorKey == 'trial_same_plan') {
            errorMsg = l.t('trial_same_plan');
          } else if (errorKey == 'plan_no_trial') {
            errorMsg = l.t('plan_no_trial');
          } else {
            errorMsg = l.t('failed_start_trial');
          }
          _showError(errorMsg);
          setState(() => _isPurchasing = false);
          return;
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l.t('trial_started').replaceAll('{days}', trialDays.toString()),
                style: GoogleFonts.manrope(fontSize: 13),
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Handle online payment (no trial)
      if (_selectedPaymentMethod == 'online') {
        // Navigate to payment screen for online payment
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.pushNamed(
            context,
            AppRoutes.paymentScreen,
            arguments: {
              'amount': amount,
              'planId': _selectedPlanId,
              'providerId': providerId,
              'isPlanPurchase': true,
            },
          );
        }
        return;
      }

      // Handle manual payments (bank transfer / cash deposit)
      if (_receiptFile == null) {
        _showError(l.t('please_upload_receipt'));
        setState(() => _isPurchasing = false);
        return;
      }

      // Create subscription
      final subscription = await SupabaseService.instance.createProviderSubscription(
        providerId: providerId,
        planId: _selectedPlanId!,
        paymentMethod: _selectedPaymentMethod!,
        amount: amount,
        billingCycle: _billingCycle,
      );

      if (subscription == null) {
        _showError('Failed to create subscription');
        setState(() => _isPurchasing = false);
        return;
      }

      // Upload receipt
      final receiptUrl = await SupabaseService.instance.uploadPaymentReceipt(
        subscription['id'] as String,
        _receiptFile!.path,
      );

      if (receiptUrl == null) {
        _showError(l.t('failed_upload_receipt'));
        setState(() => _isPurchasing = false);
        return;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('payment_submitted'),
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _showError('${l.t('failed_create_subscription')}: $e');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope(fontSize: 13)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodTitle(String methodType) {
    final l = LocalizationService.instance;
    switch (methodType) {
      case 'online':
        return l.t('online_payment');
      case 'bank_transfer':
        return l.t('bank_transfer');
      case 'cash_deposit':
        return l.t('cash_deposit');
      default:
        return methodType;
    }
  }

  IconData _getPaymentMethodIcon(String methodType) {
    switch (methodType) {
      case 'online':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cash_deposit':
        return Icons.payments_outlined;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    if (_isLoading) {
      return Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.t('loading')),
            ],
          ),
        ),
      );
    }

    if (_documentsNotVerified) {
      return Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 48, color: AppTheme.warning),
              const SizedBox(height: 16),
              Text(
                l.t('documents_not_verified'),
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.t('documents_required_desc'),
                style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.t('cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.providerDocumentsScreen);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        l.t('upload_document'),
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('choose_your_plan'),
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          l.t('plan_desc'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Content
            if (!_showProviderPlanPricing)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_browser_rounded,
                        size: 56,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.t('manage_plans'),
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.t('manage_plans_not_configured'),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _providerPlanManagementUrl.isNotEmpty
                              ? () async {
                                  final uri = Uri.parse(_providerPlanManagementUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            l.t('manage_plans'),
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plans Section
                      Text(
                        l.t('available_plans'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Billing Cycle Toggle - Shows highest discount from available plans
                    Builder(builder: (context) {
                      final maxDiscount = _plans.fold<int>(0, (max, plan) {
                        final discount = (plan['yearly_discount_percent'] as num?)?.toInt() ?? 0;
                        return discount > max ? discount : max;
                      });
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _billingCycle = 'monthly'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _billingCycle == 'monthly' ? AppTheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    l.t('monthly'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _billingCycle == 'monthly' ? Colors.white : AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _billingCycle = 'yearly'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _billingCycle == 'yearly' ? AppTheme.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        l.t('yearly'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _billingCycle == 'yearly' ? Colors.white : AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (maxDiscount > 0)
                                        Text(
                                          '${l.t('save_up_to')} $maxDiscount%',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _billingCycle == 'yearly' ? Colors.white.withAlpha(200) : AppTheme.success,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    ..._plans.map((plan) {
                      final isSelected = _selectedPlanId == plan['id'];
                      final priceMonthly = (plan['price_monthly'] as num?)?.toDouble() ?? 0.0;
                      final priceYearly = (plan['price_yearly'] as num?)?.toDouble();
                      final displayPrice = _billingCycle == 'yearly' && priceYearly != null
                          ? priceYearly / 12
                          : priceMonthly;
                      final isCurrentPlan = widget.currentPlanId == plan['id'];

                      // Extract plan features
                      final trialDays = (plan['trial_days'] as num?)?.toInt() ?? 0;
                      final priorityLevel = (plan['priority_level'] as num?)?.toInt() ?? 0;
                      final maxCategories = (plan['max_categories'] as num?)?.toInt();
                      final maxJobRequests = (plan['max_job_requests'] as num?)?.toInt();
                      final features = (plan['features'] as List<dynamic>?)?.cast<String>() ?? [];
                      final yearlyDiscount = (plan['yearly_discount_percent'] as num?)?.toInt();

                      return GestureDetector(
                        onTap: () => setState(() => _selectedPlanId = plan['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primary : AppTheme.outline,
                                        width: 2,
                                      ),
                                      color: isSelected ? AppTheme.primary : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                l.translateContent(
                                                  plan['name_translations'] as Map<String, dynamic>?,
                                                  fallbackText: plan['name'] as String? ?? l.t('unnamed_plan'),
                                                ),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.onSurface,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCurrentPlan) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.success,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  l.t('current').toUpperCase(),
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (plan['description'] != null)
                                          Text(
                                            plan['description'] as String,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: AppTheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${displayPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      Text(
                                        '/${_billingCycle == 'yearly' ? l.t('billed_yearly') : l.t('per_month').replaceAll('/', '')}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_billingCycle == 'yearly' && yearlyDiscount != null && yearlyDiscount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            l.t('yearly_discount').replaceAll('{discount}', yearlyDiscount.toString()),
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              // Plan Features
                              if (trialDays > 0 || priorityLevel > 0 || maxCategories != null || features.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (trialDays > 0)
                                      _buildFeatureChip(
                                        Icons.calendar_today_outlined,
                                        '$trialDays ${l.t('trial_days_suffix')}',
                                        AppTheme.primary,
                                      ),
                                    if (priorityLevel > 0)
                                      _buildFeatureChip(
                                        Icons.priority_high,
                                        '${l.t('priority_suffix')} $priorityLevel',
                                        AppTheme.warning,
                                      ),
                                    if (maxCategories != null)
                                      _buildFeatureChip(
                                        Icons.category_outlined,
                                        '$maxCategories ${l.t('max_categories_suffix')}',
                                        AppTheme.secondary,
                                      ),
                                    if (maxJobRequests != null)
                                      _buildFeatureChip(
                                        Icons.work_outline,
                                        '$maxJobRequests ${l.t('jobs_per_month_suffix')}',
                                        AppTheme.primaryLight,
                                      ),
                                    ...features.map((feature) => _buildFeatureChip(
                                      Icons.check_circle_outline,
                                      feature,
                                      AppTheme.success,
                                    )),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Payment Methods Section
                    if (_selectedPlanId != null) ...[
                      Builder(builder: (context) {
                        final selectedPlan = _plans.firstWhere((p) => p['id'] == _selectedPlanId);
                        final trialDays = (selectedPlan['trial_days'] as num?)?.toInt() ?? 0;
                        
                        if (trialDays > 0) {
                          // Determine trial eligibility
                          final canTrial = !_trialUsed ||
                              (_trialResetAllowed && _trialPlanId != _selectedPlanId);

                          if (canTrial) {
                            // Show trial available info
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.successContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.success.withAlpha(50)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.celebration, color: AppTheme.success, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.t('trial_available'),
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          l.t('trial_desc').replaceAll('{days}', trialDays.toString()),
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Trial not available — show warning
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.warningContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.warning.withAlpha(50)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppTheme.warning, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.t('trial_not_available'),
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          l.t('trial_not_available_desc'),
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        
                        // Show payment methods for non-trial plans
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.t('payment_method'),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Online payment option (always available)
                            GestureDetector(
                              onTap: () => setState(() => _selectedPaymentMethod = 'online'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _selectedPaymentMethod == 'online'
                                      ? AppTheme.successContainer
                                      : AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedPaymentMethod == 'online'
                                        ? AppTheme.success
                                        : AppTheme.outlineVariant,
                                    width: _selectedPaymentMethod == 'online' ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.credit_card,
                                      color: _selectedPaymentMethod == 'online'
                                          ? AppTheme.success
                                          : AppTheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        l.t('online_payment'),
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (_selectedPaymentMethod == 'online')
                                      const Icon(Icons.check_circle, color: AppTheme.success),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Manual payment methods
                            ..._paymentMethods.map((method) {
                              final methodType = method['method_type'] as String;
                              final isSelected = _selectedPaymentMethod == methodType;
                              final instructions = method['instructions'] as String? ?? '';

                              return GestureDetector(
                                onTap: () => setState(() => _selectedPaymentMethod = methodType),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.successContainer
                                        : AppTheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.success : AppTheme.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getPaymentMethodIcon(methodType),
                                            color: isSelected ? AppTheme.success : AppTheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _getPaymentMethodTitle(methodType),
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check_circle, color: AppTheme.success),
                                        ],
                                      ),
                                      if (isSelected && instructions.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.outlineVariant),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l.t('payment_instructions'),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                instructions,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13,
                                                  color: AppTheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: _pickReceipt,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _receiptFile != null
                                                  ? AppTheme.successContainer
                                                  : AppTheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _receiptFile != null
                                                    ? AppTheme.success
                                                    : AppTheme.primary,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _receiptFile != null ? Icons.check : Icons.upload_file,
                                                  color: _receiptFile != null
                                                      ? AppTheme.success
                                                      : AppTheme.primary,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _receiptFile != null
                                                      ? l.t('receipt_uploaded')
                                                      : l.t('upload_receipt'),
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _receiptFile != null
                                                        ? AppTheme.success
                                                        : AppTheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer buttons
            if (!_showProviderPlanPricing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l.t('close'),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isPurchasing ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          l.t('cancel'),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Builder(builder: (context) {
                        final selectedPlan = _selectedPlanId != null
                            ? _plans.firstWhere((p) => p['id'] == _selectedPlanId, orElse: () => {})
                            : {};
                        final trialDays = (selectedPlan['trial_days'] as num?)?.toInt() ?? 0;
                        final hasTrial = trialDays > 0;
                        final canTrial = hasTrial && (!_trialUsed ||
                            (_trialResetAllowed && _trialPlanId != _selectedPlanId));

                        return ElevatedButton(
                          onPressed: _isPurchasing ? null : _purchasePlan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canTrial ? AppTheme.success : AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isPurchasing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  canTrial
                                      ? l.t('start_trial').replaceAll('{days}', trialDays.toString())
                                      : l.t('purchase_plan'),
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
