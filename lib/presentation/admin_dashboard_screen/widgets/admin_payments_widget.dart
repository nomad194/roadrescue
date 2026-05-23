import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminPaymentsWidget extends StatefulWidget {
  const AdminPaymentsWidget({super.key});

  @override
  State<AdminPaymentsWidget> createState() => _AdminPaymentsWidgetState();
}

class _AdminPaymentsWidgetState extends State<AdminPaymentsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  bool _commissionEnabled = true;
  double _commissionPercent = 15.0;
  bool _savingCommission = false;

  bool _postPaymentOnline = true;
  bool _postPaymentCash = false;
  bool _savingPostPayment = false;

  bool _whatsappEnabled = true;
  bool _savingWhatsapp = false;

  List<Map<String, dynamic>> _plans = [];
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    _loadSettings();
    _loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', [
            'commission_enabled',
            'commission_percent',
            'post_payment_screen_online',
            'post_payment_screen_cash',
            'whatsapp_chat_enabled',
          ]);

      for (final row in response as List) {
        if (row['setting_key'] == 'commission_enabled') {
          setState(() => _commissionEnabled = row['setting_value'] == 'true');
        } else if (row['setting_key'] == 'commission_percent') {
          setState(
            () => _commissionPercent =
                double.tryParse(row['setting_value'] as String) ?? 15.0,
          );
        } else if (row['setting_key'] == 'post_payment_screen_online') {
          setState(() => _postPaymentOnline = row['setting_value'] == 'true');
        } else if (row['setting_key'] == 'post_payment_screen_cash') {
          setState(() => _postPaymentCash = row['setting_value'] == 'true');
        } else if (row['setting_key'] == 'whatsapp_chat_enabled') {
          setState(() => _whatsappEnabled = row['setting_value'] == 'true');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .order('price_monthly', ascending: true);
      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(response);
          _loadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _saveCommissionSettings() async {
    setState(() => _savingCommission = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'commission_enabled',
          'setting_value': _commissionEnabled.toString(),
        },
        {
          'setting_key': 'commission_percent',
          'setting_value': _commissionPercent.toString(),
        },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission settings saved'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Commission save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCommission = false);
    }
  }

  Future<void> _savePostPaymentSettings() async {
    setState(() => _savingPostPayment = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'post_payment_screen_online',
          'setting_value': _postPaymentOnline.toString(),
        },
        {
          'setting_key': 'post_payment_screen_cash',
          'setting_value': _postPaymentCash.toString(),
        },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment screen preferences saved'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
    setState(() => _savingPostPayment = false);
  }

  Future<void> _saveWhatsappSettings() async {
    setState(() => _savingWhatsapp = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'whatsapp_chat_enabled',
          'setting_value': _whatsappEnabled.toString(),
        },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp feature status saved'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
    setState(() => _savingWhatsapp = false);
  }

  void _showAddEditPlanDialog({Map<String, dynamic>? plan}) {
    final l = LocalizationService.instance;
    final nameCtrl = TextEditingController(text: plan?['name'] ?? '');
    final priceMCtrl = TextEditingController(
      text: plan?['price_monthly']?.toString() ?? '',
    );
    final priceYCtrl = TextEditingController(
      text: plan?['price_yearly']?.toString() ?? '',
    );
    final trialCtrl = TextEditingController(
      text: plan?['trial_days']?.toString() ?? AppConstants.defaultTrialDays.toString(),
    );
    final discountCtrl = TextEditingController(
      text: plan?['discount_percent']?.toString() ?? AppConstants.defaultDiscountPercent.toString(),
    );
    final maxRadiusCtrl = TextEditingController(
      text: plan?['max_radius_miles']?.toString() ?? AppConstants.defaultMaxRadiusMiles.toString(),
    );
    final maxCategoriesCtrl = TextEditingController(
      text: plan?['max_categories']?.toString() ?? AppConstants.defaultMaxCategories.toString(),
    );
    final featureAddCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: plan?['badge_text'] ?? '');

    Map<String, String> nameTranslations = Map<String, String>.from(
      plan?['name_translations'] ?? {},
    );
    String _selectedLangCode = LocalizationService.instance.defaultLanguage;
    List<String> features = List<String>.from(plan?['features'] ?? []);
    bool isActive = plan?['is_active'] ?? true;
    bool isFeatured = plan?['is_featured'] ?? false;
    bool canUseAfterHours = plan?['can_use_after_hours'] ?? false;
    bool canSetDistanceSurcharges =
        plan?['can_set_distance_surcharges'] ?? false;
    int priorityLevel = plan?['priority_level'] ?? 0;
    String purchaseMode = plan?['purchase_mode'] ?? 'in_app';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            plan == null ? 'Add Subscription Plan' : 'Edit Plan',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Name',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: Text(
                      nameTranslations[_selectedLangCode]?.isNotEmpty == true
                          ? nameTranslations[_selectedLangCode]!
                          : (nameCtrl.text.isNotEmpty ? nameCtrl.text : '—'),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MultilingualTabsWidget(
                    initialTranslations: nameTranslations,
                    fieldLabel: 'Name Translations',
                    hint: 'Plan name in other languages',
                    onChanged: (updated) {
                      nameTranslations = updated;
                      setDialogState(() {});
                    },
                    onTabChanged: (code) => setDialogState(() => _selectedLangCode = code),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          priceMCtrl,
                          'Monthly (\$)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          priceYCtrl,
                          'Yearly (\$)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          trialCtrl,
                          'Trial (Days)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          discountCtrl,
                          'Discount (%)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          badgeCtrl,
                          'Badge Text',
                          hint: 'e.g. Most Popular',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority Level',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: priorityLevel,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppTheme.outline,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('None')),
                                DropdownMenuItem(value: 1, child: Text('Low')),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(value: 3, child: Text('High')),
                              ],
                              onChanged: (v) =>
                                  setDialogState(() => priorityLevel = v!),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          maxRadiusCtrl,
                          'Max Radius (mi)',
                          hint: 'e.g. 50',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          maxCategoriesCtrl,
                          'Max Categories',
                          hint: 'e.g. 3',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_toggle_off,
                        size: 18,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'After-Hours Rates',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: canUseAfterHours,
                        onChanged: (v) =>
                            setDialogState(() => canUseAfterHours = v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.add_road_outlined,
                        size: 18,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Distance Surcharges',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: canSetDistanceSurcharges,
                        onChanged: (v) =>
                            setDialogState(() => canSetDistanceSurcharges = v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Features List',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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
                                    f,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setDialogState(() => features.remove(f)),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                    color: AppTheme.error,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: featureAddCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Add a feature...',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (featureAddCtrl.text.isNotEmpty) {
                                  setDialogState(() {
                                    features.add(featureAddCtrl.text.trim());
                                    featureAddCtrl.clear();
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('purchase_mode'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: purchaseMode,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.outline,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'in_app',
                            child: Text('In-App Purchase'),
                          ),
                          DropdownMenuItem(
                            value: 'external',
                            child: Text('External Link'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => purchaseMode = v!),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Show featured badge'),
                      const Spacer(),
                      Switch(
                        value: isFeatured,
                        onChanged: (v) => setDialogState(() => isFeatured = v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Set plan as active'),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final Map<String, dynamic> data = {
                  'name': nameCtrl.text.trim(),
                  'name_translations': nameTranslations,
                  'price_monthly': double.tryParse(priceMCtrl.text) ?? 0.0,
                  'price_yearly': double.tryParse(priceYCtrl.text),
                  'trial_days': int.tryParse(trialCtrl.text) ?? 0,
                  'discount_percent': int.tryParse(discountCtrl.text) ?? 0, // Fixed: int not double
                  'features': features,
                  'is_active': isActive,
                  'is_featured': isFeatured,
                  'purchase_mode': purchaseMode,
                  'badge_text': badgeCtrl.text.trim(),
                  'priority_level': priorityLevel,
                  'max_radius_miles': int.tryParse(maxRadiusCtrl.text) ?? 25,
                  'max_categories': int.tryParse(maxCategoriesCtrl.text) ?? 2,
                  'can_use_after_hours': canUseAfterHours,
                  'can_set_distance_surcharges': canSetDistanceSurcharges,
                  'updated_at': DateTime.now().toIso8601String(),
                };
                debugPrint('Saving plan data: $data');
                debugPrint('Plan ID: ${plan?['id']}');
                debugPrint('Current user: ${Supabase.instance.client.auth.currentUser?.id}');
                try {
                  if (plan == null) {
                    final result = await Supabase.instance.client
                        .from('subscription_plans')
                        .insert(data)
                        .select();
                    debugPrint('Insert result: $result');
                  } else {
                    debugPrint('Updating plan with ID: ${plan['id']}');
                    final result = await Supabase.instance.client
                        .from('subscription_plans')
                        .update(data)
                        .eq('id', plan['id'])
                        .select();
                    debugPrint('Update result: $result');
                    if (result.isEmpty) {
                      debugPrint('WARNING: No rows updated - check RLS policy or plan ID');
                    }
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan saved successfully!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                    _loadPlans();
                  }
                } catch (e) {
                  debugPrint('Save plan error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Save failed: $e'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payments & Billing',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    'Manage commission, plans, and payouts',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildInnerTab(0, Icons.percent, l.t('commission')),
              _buildInnerTab(
                1,
                Icons.card_membership,
                l.t('subscription_plans'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _selectedTab == 0
            ? _buildCommissionTab(l)
            : _buildSubscriptionPlansTab(l),
      ],
    );
  }

  Widget _buildInnerTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionTab(LocalizationService l) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stripe Connect Split Payments',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Payments are automatically split between providers and the platform',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.primary.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _commissionEnabled
                          ? AppTheme.primaryContainer
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.percent,
                      size: 18,
                      color: _commissionEnabled
                          ? AppTheme.primary
                          : AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('commission_enabled'),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          _commissionEnabled
                              ? 'Fees are deducted from provider payouts'
                              : 'Platform is currently fee-free',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _commissionEnabled,
                    onChanged: (v) => setState(() => _commissionEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
              if (_commissionEnabled) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('commission_percent'),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Percentage taken from every successful job',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        onChanged: (v) =>
                            _commissionPercent = double.tryParse(v) ?? 15,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          suffixText: '%',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                        controller: TextEditingController(
                          text: _commissionPercent.toStringAsFixed(0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savingCommission ? null : _saveCommissionSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: _savingCommission
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.t('save')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('System Settings'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            children: [
              _buildSettingToggle(
                Icons.chat_bubble_outline_rounded,
                'WhatsApp Direct Chat',
                'Allow customers to chat with providers on WhatsApp',
                _whatsappEnabled,
                (v) => setState(() => _whatsappEnabled = v),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildSettingToggle(
                Icons.receipt_long_outlined,
                'Post-Payment Screen (Online)',
                'Show summary after card payments',
                _postPaymentOnline,
                (v) => setState(() => _postPaymentOnline = v),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildSettingToggle(
                Icons.money_outlined,
                'Post-Payment Screen (Cash)',
                'Show summary after cash payments',
                _postPaymentCash,
                (v) => setState(() => _postPaymentCash = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _savingWhatsapp ? null : _saveWhatsappSettings,
                      child: _savingWhatsapp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Chat Settings'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savingPostPayment
                          ? null
                          : _savePostPaymentSettings,
                      child: _savingPostPayment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Summary Settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionPlansTab(LocalizationService l) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(l.t('subscription_plans')),
            TextButton.icon(
              onPressed: () => _showAddEditPlanDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.t('add_plan')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingPlans)
          const Center(child: CircularProgressIndicator())
        else if (_plans.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No subscription plans created yet',
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final plan = _plans[i];
              return _buildPlanItem(plan, l);
            },
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> plan, LocalizationService l) {
    final bool active = plan['is_active'] ?? true;
    final String badge = plan['badge_text'] ?? '';
    return Dismissible(
      key: ValueKey(plan['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Plan?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          debugPrint('Deleting plan: ${plan['id']}');
          await Supabase.instance.client
              .from('subscription_plans')
              .delete()
              .eq('id', plan['id']);
          debugPrint('Plan deleted successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Plan deleted'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('Delete plan error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Delete failed: $e'),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        _loadPlans();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plan['is_featured'] == true
                ? AppTheme.primary
                : AppTheme.outlineVariant,
            width: plan['is_featured'] == true ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan['name'],
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '\$${plan['price_monthly']}/mo · \$${plan['price_yearly']}/yr',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _showAddEditPlanDialog(plan: plan),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniLimit(
                  Icons.map_outlined,
                  '${plan['max_radius_miles']} mi',
                ),
                _miniLimit(
                  Icons.category_outlined,
                  '${plan['max_categories']} cats',
                ),
                _miniLimit(
                  Icons.history_toggle_off,
                  plan['can_use_after_hours'] == true ? '24/7' : 'Bus. Hrs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLimit(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface,
      ),
    );
  }

  Widget _buildSettingToggle(
    IconData icon,
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: value ? AppTheme.successContainer : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: value ? AppTheme.success : AppTheme.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primary,
        ),
      ],
    );
  }
}
