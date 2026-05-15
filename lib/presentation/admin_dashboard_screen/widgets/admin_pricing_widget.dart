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

  final List<Map<String, dynamic>> _pricingRules = [
    {
      'id': 1,
      'name': 'Night Surcharge',
      'type': 'Time of Day',
      'category': 'All Services',
      'condition': '10 PM – 6 AM',
      'adjustment': '+25%',
      'active': true,
    },
    {
      'id': 2,
      'name': 'Long Distance Fee',
      'type': 'Distance Range',
      'category': 'Towing',
      'condition': '> 30 km',
      'adjustment': '+\$15.00',
      'active': true,
    },
    {
      'id': 3,
      'name': 'Weekend Premium',
      'type': 'Time of Day',
      'category': 'All Services',
      'condition': 'Sat & Sun',
      'adjustment': '+15%',
      'active': false,
    },
    {
      'id': 4,
      'name': 'Short Distance Discount',
      'type': 'Distance Range',
      'category': 'Fuel Delivery',
      'condition': '< 5 km',
      'adjustment': '-\$5.00',
      'active': true,
    },
  ];

  void _showAddRuleDialog() {
    final l = LocalizationService.instance;
    final nameController = TextEditingController();
    final conditionController = TextEditingController();
    final adjustmentController = TextEditingController();
    String selectedType = 'Time of Day';
    String selectedCategory = l.t('all');
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Pricing Rule',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Rule Name',
                    hintText: 'e.g. Night Surcharge',
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
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Rule Type',
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  dropdownColor: AppTheme.surface,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                  items: ['Time of Day', 'Distance Range']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Service ${l.t('categories')}',
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  dropdownColor: AppTheme.surface,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                  items:
                      [
                            l.t('all'),
                            'Towing',
                            'Flat Tire',
                            'Lockout',
                            'Fuel Delivery',
                            'Jump Start',
                          ]
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conditionController,
                  decoration: InputDecoration(
                    labelText: 'Condition',
                    hintText: selectedType == 'Time of Day'
                        ? 'e.g. 10 PM – 6 AM'
                        : 'e.g. > 30 km',
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
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adjustmentController,
                  decoration: InputDecoration(
                    labelText: 'Price Adjustment',
                    hintText: 'e.g. +25% or +\$15.00',
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
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  _pricingRules.add({
                    'id': _pricingRules.length + 1,
                    'name': nameController.text.trim(),
                    'type': selectedType,
                    'category': selectedCategory,
                    'condition': conditionController.text.trim().isEmpty
                        ? 'N/A'
                        : conditionController.text.trim(),
                    'adjustment': adjustmentController.text.trim().isEmpty
                        ? '+0%'
                        : adjustmentController.text.trim(),
                    'active': isActive,
                  });
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Dynamic ${l.t('pricing')} Rules',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showAddRuleDialog,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                '${l.t('add_plan').split(' ')[0]} Rule',
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
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pricingRules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final rule = _pricingRules[index];
            final isPositive = rule['adjustment'].toString().startsWith('+');
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rule['type'] == 'Time of Day'
                          ? AppTheme.warningContainer
                          : AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      rule['type'] == 'Time of Day'
                          ? Icons.access_time
                          : Icons.route_outlined,
                      size: 20,
                      color: rule['type'] == 'Time of Day'
                          ? AppTheme.warning
                          : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule['name'],
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          '${rule['category']} · ${rule['condition']}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    rule['adjustment'],
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? AppTheme.error : AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: rule['active'],
                    onChanged: (v) =>
                        setState(() => _pricingRules[index]['active'] = v),
                    activeThumbColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
