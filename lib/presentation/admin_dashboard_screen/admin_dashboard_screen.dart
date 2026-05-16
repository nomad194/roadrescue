import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import './widgets/admin_categories_widget.dart';
import './widgets/admin_geo_zones_widget.dart';
import './widgets/admin_providers_widget.dart';
import './widgets/admin_pricing_widget.dart';
import './widgets/admin_transactions_widget.dart';
import './widgets/admin_app_config_widget.dart';
import './widgets/admin_payments_widget.dart';
import '../../widgets/language_selector_widget.dart';
import '../../services/localization_service.dart';

import '../../services/supabase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  List<Map<String, dynamic>> get _tabs => [
    {
      'label': LocalizationService.instance.t('categories'),
      'icon': Icons.category_outlined,
    },
    {
      'label': LocalizationService.instance.t('geo_zones'),
      'icon': Icons.map_outlined,
    },
    {
      'label': LocalizationService.instance.t('providers'),
      'icon': Icons.verified_user_outlined,
    },
    {
      'label': LocalizationService.instance.t('pricing'),
      'icon': Icons.price_change_outlined,
    },
    {
      'label': LocalizationService.instance.t('payment'),
      'icon': Icons.credit_card_outlined
    },
    {
      'label': LocalizationService.instance.t('transactions'),
      'icon': Icons.receipt_long_outlined,
    },
    {
      'label': LocalizationService.instance.t('app_config'),
      'icon': Icons.settings_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
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
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.signUpLoginScreen,
            (route) => false,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.t('admin_panel'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  LocalizationService.instance.t('roadrescue_management'),
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const LanguageSelectorWidget(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await SupabaseService.instance.signOut();
              if (!nav.context.mounted) return;
              nav.pushNamedAndRemoveUntil(
                AppRoutes.signUpLoginScreen,
                (route) => false,
              );
            },
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppTheme.error,
            ),
            tooltip: LocalizationService.instance.t('sign_out'),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.successContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  LocalizationService.instance.t('admin'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = _selectedTab == index;
                  return GestureDetector(
                    onTap: () {
                      _tabController.animateTo(index);
                      setState(() => _selectedTab = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 4, bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tabs[index]['icon'] as IconData,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tabs[index]['label'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabContent(child: AdminCategoriesWidget()),
          _TabContent(child: AdminGeoZonesWidget()),
          _TabContent(child: AdminProvidersWidget()),
          _TabContent(child: AdminPricingWidget()),
          _TabContent(child: AdminPaymentsWidget()),
          _TabContent(child: AdminTransactionsWidget()),
          _TabContent(child: AdminAppConfigWidget()),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final Widget child;
  const _TabContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
