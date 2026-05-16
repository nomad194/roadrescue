import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

import '../../services/supabase_service.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _activeSubscription;
  String _billingCycle = 'monthly';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadPlans(),
      _loadActiveSubscription(),
    ]);
  }

  Future<void> _loadActiveSubscription() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    
    final sub = await SupabaseService.instance.getActiveSubscription(userId);
    if (mounted) {
      setState(() => _activeSubscription = sub);
    }
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price_monthly', ascending: true);
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
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
          l.t('subscription_plans'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Billing toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildBillingToggle(
                          'monthly',
                          l.t('per_month').replaceAll('/', ''),
                        ),
                        _buildBillingToggle(
                          'yearly',
                          '${l.t('per_year').replaceAll('/', '')} (Save 20%)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_plans.isEmpty)
                    Center(
                      child: Text(
                        l.t('none'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...List.generate(
                      _plans.length,
                      (i) => _buildPlanCard(_plans[i], i, l),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBillingToggle(String cycle, String label) {
    final isSelected = _billingCycle == cycle;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _billingCycle = cycle),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    Map<String, dynamic> plan,
    int index,
    LocalizationService l,
  ) {
    final String badgeText = plan['badge_text'] as String? ?? '';
    final bool isFeatured = plan['is_featured'] as bool? ?? false;
    
    // Check if this is the active plan
    final bool isCurrentPlan = _activeSubscription != null && 
                             _activeSubscription!['plan_id'] == plan['id'];

    // Use popular flag, current status, or index
    final isPopular = isFeatured || index == 1 || badgeText.isNotEmpty || isCurrentPlan;

    final priceMonthly = (plan['price_monthly'] as num?)?.toDouble() ?? 0;
    final priceYearly = (plan['price_yearly'] as num?)?.toDouble();
    final trialDays = plan['trial_days'] as int? ?? 0;
    final discountPercent = (plan['discount_percent'] as num?)?.toDouble() ?? 0;
    
    // Limits & Rules
    final maxServices = plan['max_services'] as int? ?? 5;
    final maxCategories = plan['max_categories'] as int? ?? 2;
    final maxRadius = plan['max_radius_miles'] as int? ?? 25;
    final hasAfterHours = plan['can_use_after_hours'] as bool? ?? false;
    final canSetDistanceSurcharges = plan['can_set_distance_surcharges'] as bool? ?? false;
    final priorityLevel = plan['priority_level'] as int? ?? 0;

    final features = (plan['features'] as List<dynamic>?) ?? [];
    final purchaseMode = plan['purchase_mode'] as String? ?? 'in_app';
    final externalUrl = plan['external_url'] as String? ?? '';

    // Use multilingual name/description if available, fallback to plain text
    final nameTranslations = plan['name_translations'] as Map<String, dynamic>?;
    final descTranslations =
        plan['description_translations'] as Map<String, dynamic>?;
    final displayName = nameTranslations != null
        ? l.translateContent(
            nameTranslations,
            fallbackText: plan['name'] as String? ?? '',
          )
        : (plan['name'] as String? ?? '');
    final displayDesc = descTranslations != null
        ? l.translateContent(
            descTranslations,
            fallbackText: plan['description'] as String? ?? '',
          )
        : (plan['description'] as String? ?? '');

    final displayPrice = _billingCycle == 'yearly' && priceYearly != null
        ? priceYearly / 12
        : priceMonthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan 
              ? Colors.blue 
              : (isPopular ? AppTheme.primary : AppTheme.outlineVariant),
          width: (isPopular || isCurrentPlan) ? 2 : 1,
        ),
        boxShadow: (isPopular || isCurrentPlan)
            ? [
                BoxShadow(
                  color: (isCurrentPlan ? Colors.blue : AppTheme.primary).withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCurrentPlan || isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentPlan ? Colors.blue : AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Text(
                isCurrentPlan 
                    ? l.t('current_plan') 
                    : (badgeText.isNotEmpty ? badgeText : l.t('most_popular')),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          if (displayDesc.isNotEmpty)
                            Text(
                              displayDesc,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              displayPrice.toStringAsFixed(2),
                              style: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          l.t('per_month'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (discountPercent > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${discountPercent.toInt()}% ${l.t('discount')}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                ],
                if (trialDays > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_outline,
                        size: 14,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$trialDays ${l.t('days_free')} ${l.t('free_trial')}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(color: AppTheme.outlineVariant),
                const SizedBox(height: 10),
                
                // Limits Icons
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildPlanLimit(Icons.build_circle_outlined, maxServices == 0 ? 'Unlimited Services' : '$maxServices Services'),
                    _buildPlanLimit(Icons.category_outlined, maxCategories == 0 ? 'Unlimited Categories' : '$maxCategories Categories'),
                    _buildPlanLimit(Icons.map_outlined, maxRadius == 0 ? 'Global' : '$maxRadius mi range'),
                    if (canSetDistanceSurcharges)
                      _buildPlanLimit(Icons.add_road_outlined, 'Extra Range Fees'),
                    if (priorityLevel > 0)
                      _buildPlanLimit(Icons.priority_high_rounded, 'Priority ${priorityLevel == 3 ? 'High' : priorityLevel == 2 ? 'Med' : 'Low'}'),
                    if (hasAfterHours)
                      _buildPlanLimit(Icons.nights_stay_outlined, 'After-Hours'),
                  ],
                ),
                const SizedBox(height: 14),

                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.toString(),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan 
                        ? null 
                        : () => _handleSubscribe(plan, purchaseMode, externalUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? Colors.blue.withAlpha(20)
                          : (isPopular ? AppTheme.primary : AppTheme.surface),
                      foregroundColor: isCurrentPlan
                          ? Colors.blue
                          : (isPopular ? Colors.white : AppTheme.primary),
                      side: (isPopular || isCurrentPlan)
                          ? null
                          : const BorderSide(color: AppTheme.primary),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isCurrentPlan
                          ? l.t('current_plan')
                          : (trialDays > 0
                              ? '${l.t('free_trial')} · ${l.t('subscribe')}'
                              : l.t('subscribe')),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanLimit(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _handleSubscribe(
    Map<String, dynamic> plan,
    String purchaseMode,
    String externalUrl,
  ) {
    final l = LocalizationService.instance;
    if (purchaseMode == 'external' && externalUrl.isNotEmpty) {
      // Show external link dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            plan['name'] as String? ?? '',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This plan is available on our website.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  externalUrl,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('close'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    } else {
      // In-app subscription flow
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscribing to ${plan['name']}...',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppTheme.primary,
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
