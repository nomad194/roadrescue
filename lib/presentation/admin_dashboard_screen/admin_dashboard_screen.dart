import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import './widgets/admin_categories_widget.dart';
import './widgets/admin_geo_zones_widget.dart';
import './widgets/admin_phone_verification_widget.dart';
import './widgets/admin_providers_widget.dart';
import './widgets/admin_transactions_widget.dart';
import './widgets/admin_app_config_widget.dart';
import './widgets/admin_document_review_widget.dart';
import './widgets/admin_document_types_widget.dart';
import './widgets/admin_payments_widget.dart';
import './widgets/admin_payment_methods_widget.dart';
import './widgets/admin_users_widget.dart';
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
      'label': 'Users',
      'icon': Icons.people_outlined,
    },
    {
      'label': 'Phone Verification',
      'icon': Icons.verified_user_outlined,
    },
    {
      'label': 'Payment Methods',
      'icon': Icons.payment_outlined,
    },
    {
      'label': LocalizationService.instance.t('payment'),
      'icon': Icons.credit_card_outlined,
    },
    {
      'label': LocalizationService.instance.t('transactions'),
      'icon': Icons.receipt_long_outlined,
    },
    {
      'label': LocalizationService.instance.t('app_config'),
      'icon': Icons.settings_outlined,
    },
    {
      'label': LocalizationService.instance.t('required_documents'),
      'icon': Icons.description_outlined,
    },
    {
      'label': LocalizationService.instance.t('document_review'),
      'icon': Icons.fact_check_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LocalizationService.instance.t('admin_panel'),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                  Text(
                    'Management',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 22,
              color: AppTheme.onSurface,
            ),
            onSelected: (val) async {
              if (val == 'language') {
                LanguageSelectorWidget.showLanguageDialog(context);
              } else if (val == 'sign_out') {
                final nav = Navigator.of(context);
                await SupabaseService.instance.signOut();
                if (!nav.context.mounted) return;
                nav.pushNamedAndRemoveUntil(
                  AppRoutes.signUpLoginScreen,
                  (r) => false,
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Text(LocalizationService.instance.t('language')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sign_out',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Text(LocalizationService.instance.t('sign_out')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successContainer.withAlpha(150),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  LocalizationService.instance.t('admin').toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.success,
                  ),
                ),
              ),
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
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tabs[index]['label'] as String,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
        physics: const BouncingScrollPhysics(),
        children: const [
          RepaintBoundary(child: _TabContent(child: AdminCategoriesWidget())),
          RepaintBoundary(child: _TabContent(child: AdminGeoZonesWidget())),
          RepaintBoundary(child: _TabContent(child: AdminProvidersWidget())),
          RepaintBoundary(child: _TabContent(child: AdminUsersWidget())),
          RepaintBoundary(child: _TabContent(child: AdminPhoneVerificationWidget())),
          RepaintBoundary(child: _TabContent(child: AdminPaymentMethodsWidget())),
          RepaintBoundary(child: _TabContent(child: AdminPaymentsWidget())),
          RepaintBoundary(child: _TabContent(child: AdminTransactionsWidget())),
          RepaintBoundary(child: _TabContent(child: AdminAppConfigWidget())),
          RepaintBoundary(child: _TabContent(child: AdminDocumentTypesWidget())),
          RepaintBoundary(child: _TabContent(child: AdminDocumentReviewWidget())),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: constraints.maxWidth - 32,
            child: child,
          ),
        );
      },
    );
  }
}
