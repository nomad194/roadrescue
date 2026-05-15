import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Commission settings
  bool _commissionEnabled = true;
  double _commissionPercent = 15.0;
  bool _savingCommission = false;

  // Post-payment screen toggles
  bool _postPaymentOnline = true;
  bool _postPaymentCash = false;
  bool _savingPostPayment = false;

  // WhatsApp feature toggle
  bool _whatsappEnabled = true;
  bool _savingWhatsapp = false;

  // Subscription plans
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

  Future<void> _saveCommissionSettings() async {
    setState(() => _savingCommission = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'commission_enabled',
          'setting_value': _commissionEnabled.toString(),
          'setting_type': 'boolean',
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'setting_key': 'commission_percent',
          'setting_value': _commissionPercent.toStringAsFixed(1),
          'setting_type': 'number',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ], onConflict: 'setting_key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Commission settings saved!',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings',
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
          'setting_type': 'boolean',
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'setting_key': 'post_payment_screen_cash',
          'setting_value': _postPaymentCash.toString(),
          'setting_type': 'boolean',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ], onConflict: 'setting_key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Post-payment settings saved!',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings',
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
      if (mounted) setState(() => _savingPostPayment = false);
    }
  }

  Future<void> _saveWhatsappSettings() async {
    setState(() => _savingWhatsapp = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'whatsapp_chat_enabled',
          'setting_value': _whatsappEnabled.toString(),
          'setting_type': 'boolean',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ], onConflict: 'setting_key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WhatsApp settings saved!',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings',
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
      if (mounted) setState(() => _savingWhatsapp = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payments & Subscriptions',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        Text(
          'Configure commission, Stripe Connect, and provider plans',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Inner tabs
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
        // Stripe Connect info
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

        // Commission toggle
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
                              ? 'Platform takes ${_commissionPercent.toStringAsFixed(0)}% of each payment'
                              : 'Providers receive 100% of payments',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
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
                const Divider(color: AppTheme.outlineVariant),
                const SizedBox(height: 12),
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
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Text(
                            'Drag to set platform commission (0–50%)',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_commissionPercent.toStringAsFixed(0)}%',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _commissionPercent,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.outlineVariant,
                  onChanged: (v) => setState(() => _commissionPercent = v),
                ),
                // Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Example: \$100 payment',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Platform earns:',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '\$${_commissionPercent.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Provider earns:',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '\$${(100 - _commissionPercent).toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _savingCommission ? null : _saveCommissionSettings,
            icon: _savingCommission
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _savingCommission ? 'Saving...' : l.t('save'),
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Post-payment screen settings
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
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
                          'Post-Payment Receipt Screen',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Choose which payment methods show the receipt screen',
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
              const SizedBox(height: 16),
              const Divider(color: AppTheme.outlineVariant),
              const SizedBox(height: 12),
              _buildPostPaymentToggle(
                icon: Icons.credit_card_rounded,
                label: 'Online Payment (Stripe)',
                subtitle: 'Show receipt after successful card payment',
                value: _postPaymentOnline,
                onChanged: (v) => setState(() => _postPaymentOnline = v),
              ),
              const SizedBox(height: 12),
              _buildPostPaymentToggle(
                icon: Icons.payments_outlined,
                label: 'Cash Payment',
                subtitle: 'Show receipt when customer selects cash',
                value: _postPaymentCash,
                onChanged: (v) => setState(() => _postPaymentCash = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingPostPayment
                      ? null
                      : _savePostPaymentSettings,
                  icon: _savingPostPayment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _savingPostPayment ? 'Saving...' : 'Save Receipt Settings',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // WhatsApp Chat toggle
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _whatsappEnabled
                          ? const Color(0xFF25D366).withAlpha(30)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chat_rounded,
                      size: 18,
                      color: _whatsappEnabled
                          ? const Color(0xFF25D366)
                          : AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Chat Button',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          _whatsappEnabled
                              ? 'Customers can chat with providers via WhatsApp after confirmation'
                              : 'WhatsApp chat button is hidden from customers',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _whatsappEnabled,
                    onChanged: (v) => setState(() => _whatsappEnabled = v),
                    activeThumbColor: const Color(0xFF25D366),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingWhatsapp ? null : _saveWhatsappSettings,
                  icon: _savingWhatsapp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _savingWhatsapp ? 'Saving...' : 'Save WhatsApp Setting',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostPaymentToggle({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.success,
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
            Text(
              l.t('subscription_plans'),
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showPlanDialog(null),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                l.t('add_plan'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingPlans)
          const Center(child: CircularProgressIndicator())
        else if (_plans.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                'No subscription plans yet. Add one!',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildPlanCard(_plans[index], l),
          ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, LocalizationService l) {
    final isActive = plan['is_active'] as bool? ?? true;
    final trialDays = plan['trial_days'] as int? ?? 0;
    final discountPercent = (plan['discount_percent'] as num?)?.toDouble() ?? 0;
    final purchaseMode = plan['purchase_mode'] as String? ?? 'in_app';

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppTheme.outlineVariant
                : AppTheme.outline.withAlpha(80),
          ),
        ),
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
                        plan['name'] as String? ?? '',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        '\$${(plan['price_monthly'] as num?)?.toStringAsFixed(2) ?? '0.00'}/mo',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showPlanDialog(plan),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _togglePlanActive(plan),
                      icon: Icon(
                        isActive ? Icons.toggle_on : Icons.toggle_off,
                        size: 22,
                        color: isActive ? AppTheme.success : AppTheme.muted,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isActive
                            ? AppTheme.successContainer
                            : AppTheme.surfaceVariant,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (trialDays > 0)
                  _buildChip(
                    '$trialDays day trial',
                    AppTheme.warning,
                    AppTheme.warningContainer,
                  ),
                if (discountPercent > 0)
                  _buildChip(
                    '${discountPercent.toInt()}% off',
                    AppTheme.success,
                    AppTheme.successContainer,
                  ),
                _buildChip(
                  purchaseMode == 'external' ? 'External Link' : 'In-App',
                  AppTheme.primary,
                  AppTheme.primaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _togglePlanActive(Map<String, dynamic> plan) async {
    final newActive = !(plan['is_active'] as bool? ?? true);
    try {
      await Supabase.instance.client
          .from('subscription_plans')
          .update({'is_active': newActive})
          .eq('id', plan['id'] as String);
      await _loadPlans();
    } catch (_) {}
  }

  void _showPlanDialog(Map<String, dynamic>? existingPlan) {
    final l = LocalizationService.instance;

    // Multilingual name/description translations
    Map<String, String> nameTranslations = {};
    Map<String, String> descTranslations = {};

    // Pre-fill from existing plan if available
    if (existingPlan != null) {
      final existingName = existingPlan['name'] as String? ?? '';
      final existingDesc = existingPlan['description'] as String? ?? '';
      // If plan has translations map stored, use it; otherwise seed with existing text in English
      final nameMap = existingPlan['name_translations'] as Map?;
      final descMap = existingPlan['description_translations'] as Map?;
      if (nameMap != null) {
        nameTranslations = nameMap.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      } else if (existingName.isNotEmpty) {
        nameTranslations = {'en': existingName};
      }
      if (descMap != null) {
        descTranslations = descMap.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      } else if (existingDesc.isNotEmpty) {
        descTranslations = {'en': existingDesc};
      }
    }

    final priceMonthlyCtrl = TextEditingController(
      text: (existingPlan?['price_monthly'] as num?)?.toStringAsFixed(2) ?? '',
    );
    final priceYearlyCtrl = TextEditingController(
      text: (existingPlan?['price_yearly'] as num?)?.toStringAsFixed(2) ?? '',
    );
    final trialDaysCtrl = TextEditingController(
      text: (existingPlan?['trial_days'] as int?)?.toString() ?? '0',
    );
    final discountCtrl = TextEditingController(
      text:
          (existingPlan?['discount_percent'] as num?)?.toStringAsFixed(0) ??
          '0',
    );
    final externalUrlCtrl = TextEditingController(
      text: existingPlan?['external_url'] as String? ?? '',
    );
    String purchaseMode = existingPlan?['purchase_mode'] as String? ?? 'in_app';
    bool isActive = existingPlan?['is_active'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.translate, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                existingPlan == null ? l.t('add_plan') : l.t('edit_plan'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multilingual plan name
                  Text(
                    l.t('plan_name'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: nameTranslations,
                    fieldLabel: l.t('plan_name'),
                    hint: 'e.g. Professional',
                    maxLines: 1,
                    onChanged: (updated) => nameTranslations = updated,
                  ),
                  const SizedBox(height: 12),
                  // Multilingual description
                  Text(
                    l.t('description'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: descTranslations,
                    fieldLabel: l.t('description'),
                    hint: 'Short description...',
                    maxLines: 2,
                    onChanged: (updated) => descTranslations = updated,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          priceMonthlyCtrl,
                          l.t('monthly_price'),
                          hint: '9.99',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          priceYearlyCtrl,
                          l.t('yearly_price'),
                          hint: '99.99',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _dialogField(
                          trialDaysCtrl,
                          l.t('trial_days'),
                          hint: '14',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dialogField(
                          discountCtrl,
                          '${l.t('discount')} %',
                          hint: '10',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  // Purchase mode
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
                          enabledBorder: OutlineInputBorder(
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
                        dropdownColor: AppTheme.surface,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.onSurface,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'in_app',
                            child: Text(l.t('in_app')),
                          ),
                          DropdownMenuItem(
                            value: 'external',
                            child: Text(l.t('external_link')),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => purchaseMode = v!),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  if (purchaseMode == 'external')
                    _dialogField(
                      externalUrlCtrl,
                      l.t('external_url'),
                      hint: 'https://yoursite.com/plans',
                    ),
                  // Active toggle
                  Row(
                    children: [
                      Text(
                        l.t('active'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppTheme.onSurface,
                        ),
                      ),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final hasName = nameTranslations.values.any(
                  (v) => v.isNotEmpty,
                );
                if (!hasName) return;
                // Use English name as primary 'name' field for backward compat
                final primaryName =
                    nameTranslations['en'] ??
                    nameTranslations.values.firstWhere(
                      (v) => v.isNotEmpty,
                      orElse: () => '',
                    );
                final primaryDesc =
                    descTranslations['en'] ??
                    (descTranslations.values.isNotEmpty
                        ? descTranslations.values.first
                        : '');
                final planData = {
                  'name': primaryName,
                  'description': primaryDesc,
                  'name_translations': nameTranslations,
                  'description_translations': descTranslations,
                  'price_monthly': double.tryParse(priceMonthlyCtrl.text) ?? 0,
                  'price_yearly': double.tryParse(priceYearlyCtrl.text),
                  'trial_days': int.tryParse(trialDaysCtrl.text) ?? 0,
                  'discount_percent': double.tryParse(discountCtrl.text) ?? 0,
                  'purchase_mode': purchaseMode,
                  'external_url': externalUrlCtrl.text.trim(),
                  'is_active': isActive,
                  'updated_at': DateTime.now().toIso8601String(),
                };
                try {
                  if (existingPlan == null) {
                    await Supabase.instance.client
                        .from('subscription_plans')
                        .insert(planData);
                  } else {
                    await Supabase.instance.client
                        .from('subscription_plans')
                        .update(planData)
                        .eq('id', existingPlan['id'] as String);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadPlans();
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
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
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurface),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
