import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

import '../../services/supabase_service.dart';

class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _allServices = [];
  bool _isLoadingCategories = true;

  // Map of serviceId -> ServicePricing
  final Map<String, _ServicePricing> _pricingMap = {};
  // Set of enabled service IDs
  final Set<String> _enabledServices = {};

  // Subscription Info
  Map<String, dynamic>? _activeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadCategories(),
      _loadSubscription(),
    ]);
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final cats = await SupabaseService.instance.getServiceCategories();
    if (mounted) {
      setState(() {
        _allServices = cats;
        _isLoadingCategories = false;
        // Initialize pricing for any new services
        for (final s in _allServices) {
          final id = s['id'].toString();
          if (!_pricingMap.containsKey(id)) {
            _pricingMap[id] = const _ServicePricing(basePrice: 0);
          }
        }
      });
    }
  }

  Future<void> _loadSubscription() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    
    final sub = await SupabaseService.instance.getActiveSubscription(userId);
    if (mounted) {
      setState(() {
        _activeSubscription = sub;
      });
    }
  }

  void _toggleService(String id) {
    if (!_enabledServices.contains(id)) {
      // Logic for Enforcement: check category limits
      final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
      if (plan != null) {
        final maxCategories = plan['max_categories'] as int? ?? 1;
        if (maxCategories > 0 && _enabledServices.length >= maxCategories) {
          _showLimitReached('categories', maxCategories);
          return;
        }
      }
    }

    setState(() {
      if (_enabledServices.contains(id)) {
        _enabledServices.remove(id);
      } else {
        _enabledServices.add(id);
        if (_pricingMap[id]!.basePrice == 0) {
          _pricingMap[id] = const _ServicePricing(basePrice: 0);
        }
      }
    });
  }

  void _showLimitReached(String type, int limit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Text('Limit Reached'),
          ],
        ),
        content: Text('Your current plan limits you to $limit $type. Upgrade your plan to add more.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to subscription plans (optional)
            },
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
  }

  void _openPricingEditor(Map<String, dynamic> service) {
    final l = LocalizationService.instance;
    final id = service['id'].toString();
    final pricing = _pricingMap[id] ?? const _ServicePricing(basePrice: 0);
    
    // Enforcement: check features
    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final canSetDistance = plan?['can_set_distance_surcharges'] as bool? ?? false;
    final canUseAfterHours = plan?['can_use_after_hours'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PricingEditorSheet(
        service: service,
        pricing: pricing,
        canSetDistance: canSetDistance,
        canUseAfterHours: canUseAfterHours,
        onSave: (updated) {
          setState(() => _pricingMap[id] = updated);
          Navigator.pop(ctx);
          final String displayName = l.translateContent(
            service['name_translations'] as Map<String, dynamic>? ?? {},
            fallbackText: service['name'] as String? ?? '',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l.t('pricing_saved_for')} $displayName',
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
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _saveAll() {
    final l = LocalizationService.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.t('all_saved_success'),
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
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
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('my_services_pricing'),
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              l.t('configure_what_you_offer'),
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saveAll,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l.t('save_all'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: l.t('select_services_tab')),
            Tab(text: l.t('pricing_rules_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSelectServicesTab(l), _buildPricingRulesTab(l)],
      ),
    );
  }

  Widget _buildSelectServicesTab(LocalizationService l) {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.checklist_rounded,
            title: l.t('choose_your_services'),
            subtitle: 'Select all services you are able to provide',
          ),
          const SizedBox(height: 16),
          if (_allServices.isEmpty)
            const Center(child: Text('No services found.'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _allServices.length,
              itemBuilder: (context, index) {
                final service = _allServices[index];
                final id = service['id'].toString();
                final isEnabled = _enabledServices.contains(id);
                return _ServiceToggleCard(
                  service: service,
                  isEnabled: isEnabled,
                  onToggle: () => _toggleService(id),
                );
              },
            ),
          const SizedBox(height: 20),
          if (_enabledServices.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.info_outline_rounded,
              title:
                  '${l.t('active')}: ${_enabledServices.length} ${l.t('services_selected')}',
              subtitle:
                  'Go to Pricing Rules tab to set prices for each service',
            ),
            const SizedBox(height: 12),
            ...(_enabledServices.map((id) {
              final service = _allServices.firstWhere((s) => s['id'].toString() == id);
              final pricing = _pricingMap[id] ?? const _ServicePricing(basePrice: 0);
              return _QuickPriceSummaryCard(
                service: service,
                pricing: pricing,
                onEdit: () => _openPricingEditor(service),
              );
            }).toList()),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPricingRulesTab(LocalizationService l) {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    final enabledList = _allServices
        .where((s) => _enabledServices.contains(s['id'].toString()))
        .toList();
    if (enabledList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.price_change_outlined,
                size: 56,
                color: AppTheme.muted,
              ),
              const SizedBox(height: 16),
              Text(
                l.t('none'),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.t('no_services_selected_info'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.checklist_rounded, size: 16),
                label: Text(
                  l.t('select_services_tab'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.attach_money_rounded,
          title: l.t('pricing_configuration'),
          subtitle:
              'Set base price, distance rules, and time surcharges per service',
        ),
        const SizedBox(height: 16),
        ...enabledList.map((service) {
          final id = service['id'].toString();
          final pricing = _pricingMap[id] ?? const _ServicePricing(basePrice: 0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ServicePricingCard(
              service: service,
              pricing: pricing,
              onEdit: () => _openPricingEditor(service),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Service Toggle Card ───────────────────────────────────────────────────────

class _ServiceToggleCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _ServiceToggleCard({
    required this.service,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final String name = (service['name_translations'] as Map?)?[l.currentLanguageCode] ?? service['name'] ?? '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled ? AppTheme.primary : AppTheme.outlineVariant,
            width: isEnabled ? 2 : 1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? AppTheme.primary.withAlpha(30)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isEnabled ? AppTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isEnabled ? AppTheme.primary : AppTheme.outline,
                        width: 2,
                      ),
                    ),
                    child: isEnabled
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
              Text(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? AppTheme.primary : AppTheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Price Summary Card ─────────────────────────────────────────────────

class _QuickPriceSummaryCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final _ServicePricing pricing;
  final VoidCallback onEdit;

  const _QuickPriceSummaryCard({
    required this.service,
    required this.pricing,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final String name = (service['name_translations'] as Map?)?[l.currentLanguageCode] ?? service['name'] ?? '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(iconEmoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  pricing.basePrice > 0
                      ? 'Base: \$${pricing.basePrice.toStringAsFixed(0)} · ${pricing.distanceRules.length} distance rule${pricing.distanceRules.length == 1 ? '' : 's'} · ${pricing.timeSurcharges.length} surcharge${pricing.timeSurcharges.length == 1 ? '' : 's'}'
                      : 'No price set — tap to configure',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: pricing.basePrice > 0
                        ? AppTheme.muted
                        : AppTheme.warning,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l.t('edit'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service Pricing Card ─────────────────────────────────────────────────────

class _ServicePricingCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final _ServicePricing pricing;
  final VoidCallback onEdit;

  const _ServicePricingCard({
    required this.service,
    required this.pricing,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final hasPrice = pricing.basePrice > 0;
    final String name = (service['name_translations'] as Map?)?[l.currentLanguageCode] ?? service['name'] ?? '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPrice
              ? AppTheme.outlineVariant
              : AppTheme.warning.withAlpha(100),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        hasPrice
                            ? 'Base price: \$${pricing.basePrice.toStringAsFixed(0)}'
                            : 'Price not configured',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: hasPrice ? AppTheme.success : AppTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text(
                    l.t('edit'),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pricing.distanceRules.isNotEmpty ||
              pricing.timeSurcharges.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pricing.distanceRules.isNotEmpty) ...[
                    _RulesSectionLabel(
                      icon: Icons.route_rounded,
                      label: l.t('distance_rules'),
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 6),
                    ...pricing.distanceRules.map(
                      (r) => _RuleChip(
                        label:
                            '${r.fromMiles}–${r.toMiles == null ? '∞' : '${r.toMiles}'} mi: +\$${r.extraFee.toStringAsFixed(0)}',
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pricing.timeSurcharges.isNotEmpty) ...[
                    _RulesSectionLabel(
                      icon: Icons.schedule_rounded,
                      label: l.t('time_surcharges'),
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 6),
                    ...pricing.timeSurcharges.map(
                      (s) => _RuleChip(
                        label:
                            '${s.label} (${s.startHour}:00–${s.endHour}:00): +${s.isPercent ? '${s.amount.toStringAsFixed(0)}%' : '\$${s.amount.toStringAsFixed(0)}'}',
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!hasPrice) ...[
            const Divider(height: 1, color: AppTheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Set a base price to start receiving job requests',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RulesSectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RuleChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Pricing Editor Bottom Sheet ──────────────────────────────────────────────

class _PricingEditorSheet extends StatefulWidget {
  final Map<String, dynamic> service;
  final _ServicePricing pricing;
  final bool canSetDistance;
  final bool canUseAfterHours;
  final void Function(_ServicePricing) onSave;

  const _PricingEditorSheet({
    required this.service,
    required this.pricing,
    required this.canSetDistance,
    required this.canUseAfterHours,
    required this.onSave,
  });

  @override
  State<_PricingEditorSheet> createState() => _PricingEditorSheetState();
}

class _PricingEditorSheetState extends State<_PricingEditorSheet> {
  late TextEditingController _basePriceCtrl;
  late List<_DistanceRule> _distanceRules;
  late List<_TimeSurcharge> _timeSurcharges;

  @override
  void initState() {
    super.initState();
    _basePriceCtrl = TextEditingController(
      text: widget.pricing.basePrice > 0
          ? widget.pricing.basePrice.toStringAsFixed(0)
          : '',
    );
    _distanceRules = List.from(widget.pricing.distanceRules);
    _timeSurcharges = List.from(widget.pricing.timeSurcharges);
  }

  @override
  void dispose() {
    _basePriceCtrl.dispose();
    super.dispose();
  }

  void _addDistanceRule() {
    setState(() {
      _distanceRules.add(
        _DistanceRule(fromMiles: 0, toMiles: null, extraFee: 0),
      );
    });
  }

  void _removeDistanceRule(int index) {
    setState(() => _distanceRules.removeAt(index));
  }

  void _addTimeSurcharge() {
    setState(() {
      _timeSurcharges.add(
        _TimeSurcharge(
          label: 'Night Surcharge',
          startHour: 22,
          endHour: 6,
          amount: 20,
          isPercent: true,
        ),
      );
    });
  }

  void _removeTimeSurcharge(int index) {
    setState(() => _timeSurcharges.removeAt(index));
  }

  void _save() {
    final base = double.tryParse(_basePriceCtrl.text.trim()) ?? 0;
    widget.onSave(
      _ServicePricing(
        basePrice: base,
        distanceRules: _distanceRules,
        timeSurcharges: _timeSurcharges,
      ),
    );
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.service['icon'] is IconData
                      ? Icon(
                          widget.service['icon'] as IconData,
                          size: 20,
                          color: AppTheme.primary,
                        )
                      : Text(
                          widget.service['icon_emoji'] ?? '🔧',
                          style: const TextStyle(fontSize: 20),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service['name'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        l.t('pricing_configuration'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Base Price ──
            _EditorSectionTitle(
              icon: Icons.price_check_rounded,
              title: l.t('base_price_label'),
              color: AppTheme.success,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _basePriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: '${l.t('base_price_label')} (\$)',
                hintText: 'e.g. 85',
                prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                helperText: 'Starting price before any additional rules apply',
              ),
            ),
            const SizedBox(height: 24),

            // ── Distance Rules ──
            Row(
              children: [
                Expanded(
                  child: _EditorSectionTitle(
                    icon: Icons.route_rounded,
                    title: 'Distance-Range Rules',
                    color: AppTheme.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.canSetDistance ? _addDistanceRule : null,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(
                    'Add Rule',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.canSetDistance ? AppTheme.primary : AppTheme.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (!widget.canSetDistance)
               Padding(
                 padding: const EdgeInsets.only(top: 4),
                 child: Text('Upgrade plan to set extra distance fees', style: TextStyle(fontSize: 10, color: AppTheme.warning)),
               ),
            const SizedBox(height: 4),
            Text(
              'Add extra fees based on how far the customer is from you',
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
            const SizedBox(height: 10),
            if (_distanceRules.isEmpty)
              _EmptyRuleHint(
                label: 'No distance rules — tap Add Rule to create one',
              )
            else
              ...List.generate(
                _distanceRules.length,
                (i) => _DistanceRuleRow(
                  rule: _distanceRules[i],
                  index: i,
                  onChanged: (updated) =>
                      setState(() => _distanceRules[i] = updated),
                  onRemove: () => _removeDistanceRule(i),
                ),
              ),
            const SizedBox(height: 24),

            // ── Time Surcharges ──
            Row(
              children: [
                Expanded(
                  child: _EditorSectionTitle(
                    icon: Icons.schedule_rounded,
                    title: 'Time-of-Day Surcharges',
                    color: AppTheme.warning,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.canUseAfterHours ? _addTimeSurcharge : null,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(
                    'Add Surcharge',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.canUseAfterHours ? AppTheme.warning : AppTheme.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (!widget.canUseAfterHours)
               Padding(
                 padding: const EdgeInsets.only(top: 4),
                 child: Text('Upgrade plan to set after-hours rates', style: TextStyle(fontSize: 10, color: AppTheme.warning)),
               ),
            const SizedBox(height: 4),
            Text(
              'Add surcharges for specific time windows (e.g. night fee, peak hours)',
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
            const SizedBox(height: 10),
            if (_timeSurcharges.isEmpty)
              _EmptyRuleHint(
                label: 'No time surcharges — tap Add Surcharge to create one',
              )
            else
              ...List.generate(
                _timeSurcharges.length,
                (i) => _TimeSurchargeRow(
                  surcharge: _timeSurcharges[i],
                  index: i,
                  onChanged: (updated) =>
                      setState(() => _timeSurcharges[i] = updated),
                  onRemove: () => _removeTimeSurcharge(i),
                ),
              ),
            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  l.t('save'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _EditorSectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EmptyRuleHint extends StatelessWidget {
  final String label;
  const _EmptyRuleHint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Distance Rule Row ────────────────────────────────────────────────────────

class _DistanceRuleRow extends StatefulWidget {
  final _DistanceRule rule;
  final int index;
  final void Function(_DistanceRule) onChanged;
  final VoidCallback onRemove;

  const _DistanceRuleRow({
    required this.rule,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_DistanceRuleRow> createState() => _DistanceRuleRowState();
}

class _DistanceRuleRowState extends State<_DistanceRuleRow> {
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  late TextEditingController _feeCtrl;
  bool _isUnlimited = false;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(
      text: widget.rule.fromMiles > 0
          ? widget.rule.fromMiles.toStringAsFixed(0)
          : '',
    );
    _toCtrl = TextEditingController(
      text: widget.rule.toMiles != null
          ? widget.rule.toMiles!.toStringAsFixed(0)
          : '',
    );
    _feeCtrl = TextEditingController(
      text: widget.rule.extraFee > 0
          ? widget.rule.extraFee.toStringAsFixed(0)
          : '',
    );
    _isUnlimited = widget.rule.toMiles == null;
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      _DistanceRule(
        fromMiles: double.tryParse(_fromCtrl.text) ?? 0,
        toMiles: _isUnlimited ? null : double.tryParse(_toCtrl.text),
        extraFee: double.tryParse(_feeCtrl.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Rule ${widget.index + 1}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fromCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _notify(),
                  decoration: const InputDecoration(
                    labelText: 'From (mi)',
                    hintText: '0',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _toCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isUnlimited,
                  onChanged: (_) => _notify(),
                  decoration: InputDecoration(
                    labelText: 'To (mi)',
                    hintText: _isUnlimited ? '∞' : '10',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _feeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: (_) => _notify(),
                  decoration: const InputDecoration(
                    labelText: 'Extra Fee (\$)',
                    hintText: '20',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: _isUnlimited,
                  onChanged: (v) {
                    setState(() => _isUnlimited = v ?? false);
                    _notify();
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'No upper limit (long-distance fee)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Time Surcharge Row ───────────────────────────────────────────────────────

class _TimeSurchargeRow extends StatefulWidget {
  final _TimeSurcharge surcharge;
  final int index;
  final void Function(_TimeSurcharge) onChanged;
  final VoidCallback onRemove;

  const _TimeSurchargeRow({
    required this.surcharge,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_TimeSurchargeRow> createState() => _TimeSurchargeRowState();
}

class _TimeSurchargeRowState extends State<_TimeSurchargeRow> {
  late TextEditingController _labelCtrl;
  late TextEditingController _amountCtrl;
  late int _startHour;
  late int _endHour;
  late bool _isPercent;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.surcharge.label);
    _amountCtrl = TextEditingController(
      text: widget.surcharge.amount > 0
          ? widget.surcharge.amount.toStringAsFixed(0)
          : '',
    );
    _startHour = widget.surcharge.startHour;
    _endHour = widget.surcharge.endHour;
    _isPercent = widget.surcharge.isPercent;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      _TimeSurcharge(
        label: _labelCtrl.text.trim().isEmpty
            ? 'Surcharge'
            : _labelCtrl.text.trim(),
        startHour: _startHour,
        endHour: _endHour,
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        isPercent: _isPercent,
      ),
    );
  }

  String _hourLabel(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warning,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Surcharge ${widget.index + 1}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _labelCtrl,
            onChanged: (_) => _notify(),
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Night Surcharge',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Hour',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _startHour,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: List.generate(
                        24,
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(
                            _hourLabel(h),
                            style: GoogleFonts.manrope(fontSize: 13),
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => _startHour = v ?? 0);
                        _notify();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End Hour',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _endHour,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: List.generate(
                        24,
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(
                            _hourLabel(h),
                            style: GoogleFonts.manrope(fontSize: 13),
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => _endHour = v ?? 0);
                        _notify();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: (_) => _notify(),
                  decoration: InputDecoration(
                    labelText: _isPercent ? 'Amount (%)' : 'Amount (\$)',
                    hintText: _isPercent ? 'e.g. 20' : 'e.g. 15',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TypeToggleBtn(
                        label: '%',
                        selected: _isPercent,
                        onTap: () {
                          setState(() => _isPercent = true);
                          _notify();
                        },
                      ),
                      const SizedBox(width: 6),
                      _TypeToggleBtn(
                        label: '\$',
                        selected: !_isPercent,
                        onTap: () {
                          setState(() => _isPercent = false);
                          _notify();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeToggleBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.warning : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.warning : AppTheme.outline,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class _ServicePricing {
  final double basePrice;
  final List<_DistanceRule> distanceRules;
  final List<_TimeSurcharge> timeSurcharges;

  const _ServicePricing({
    required this.basePrice,
    this.distanceRules = const [],
    this.timeSurcharges = const [],
  });
}

class _DistanceRule {
  final double fromMiles;
  final double? toMiles;
  final double extraFee;

  const _DistanceRule({
    required this.fromMiles,
    required this.toMiles,
    required this.extraFee,
  });
}

class _TimeSurcharge {
  final String label;
  final int startHour;
  final int endHour;
  final double amount;
  final bool isPercent;

  const _TimeSurcharge({
    required this.label,
    required this.startHour,
    required this.endHour,
    required this.amount,
    required this.isPercent,
  });
}

