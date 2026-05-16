import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import './widgets/job_request_card_widget.dart';
import './widgets/provider_stats_header_widget.dart';
import './widgets/quote_bottom_sheet_widget.dart';

class JobRequestsScreen extends StatefulWidget {
  const JobRequestsScreen({super.key});

  @override
  State<JobRequestsScreen> createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedStatusFilter = 'new';
  int _currentTabIndex = 0;

  late AnimationController _listController;
  RealtimeChannel? _jobSubscription;

  List<_JobRequest> _jobs = [];
  
  // Services State
  List<Map<String, dynamic>> _allServices = [];
  bool _isLoadingCategories = true;
  final Map<String, _ServicePricing> _pricingMap = {};
  final Set<String> _enabledServices = {};
  Map<String, dynamic>? _activeSubscription;
  bool _isSavingServices = false;

  // Plans State
  List<Map<String, dynamic>> _availablePlans = [];
  bool _isLoadingPlans = true;
  String _billingCycle = 'monthly';

  List<_JobRequest> get _filteredJobs {
    return _jobs.where((job) {
      final matchesStatus =
          _selectedStatusFilter == 'all' || job.status == _selectedStatusFilter;
      return matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initData();
    _subscribeToJobUpdates();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadJobs(),
      _loadCategories(),
      _loadSubscription(),
      _loadPlans(),
      _loadProviderServices(),
    ]);
  }

  @override
  void dispose() {
    _listController.dispose();
    _jobSubscription?.unsubscribe();
    super.dispose();
  }

  // ─── DATA LOADING ──────────────────────────────────────────────────────────

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.getProviderJobRequests();
      if (mounted) {
        setState(() {
          _jobs = data.map(_mapToJobRequest).toList();
          _isLoading = false;
        });
        _listController.reset();
        _listController.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final cats = await SupabaseService.instance.getServiceCategories();
    if (mounted) {
      setState(() {
        _allServices = cats;
        _isLoadingCategories = false;
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
        if (sub != null) {
          _activeSubscription = sub;
        } else {
          _activeSubscription = {
            'plan': {
              'max_categories': 1,
              'can_set_distance_surcharges': false,
              'can_use_after_hours': false,
            }
          };
        }
      });
    }
  }

  Future<void> _loadProviderServices() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final configs = await SupabaseService.instance.getProviderServices(userId);
    if (mounted) {
      setState(() {
        for (final config in configs) {
          final id = config['category_id'].toString();
          _enabledServices.add(id);
          
          final distanceRules = (config['distance_rules'] as List?)?.map((r) => _DistanceRule(
            fromMiles: (r['from'] as num).toDouble(),
            toMiles: r['to'] != null ? (r['to'] as num).toDouble() : null,
            extraFee: (r['fee'] as num).toDouble(),
          )).toList() ?? [];

          final timeSurcharges = (config['time_surcharges'] as List?)?.map((s) => _TimeSurcharge(
            label: s['label'] ?? '',
            startHour: s['start'] as int,
            endHour: s['end'] as int,
            amount: (s['amount'] as num).toDouble(),
            isPercent: s['is_percent'] as bool,
          )).toList() ?? [];

          _pricingMap[id] = _ServicePricing(
            basePrice: (config['base_price'] as num).toDouble(),
            distanceRules: distanceRules,
            timeSurcharges: timeSurcharges,
          );
        }
      });
    }
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price_monthly', ascending: true);
      if (mounted) {
        setState(() {
          _availablePlans = List<Map<String, dynamic>>.from(response);
          _isLoadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  // ─── SUBSCRIPTION & REALTIME ──────────────────────────────────────────────

  void _subscribeToJobUpdates() {
    _jobSubscription = SupabaseService.instance.subscribeToJobRequestUpdates((
      record,
    ) {
      if (!mounted) return;
      final updatedJob = _mapToJobRequestFromRecord(record);
      setState(() {
        final idx = _jobs.indexWhere((j) => j.id == updatedJob.id);
        if (idx != -1) {
          _jobs[idx] = updatedJob;
        } else {
          _loadJobs();
        }
      });
    });
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  _JobRequest _mapToJobRequest(Map<String, dynamic> data) {
    final customer = data['customer'] as Map<String, dynamic>?;
    final statusStr = data['job_status'] as String? ?? 'pending';
    final mappedStatus = _mapStatus(statusStr);

    return _JobRequest(
      id: data['id'] as String,
      serviceType: data['service_type'] as String? ?? '',
      serviceIcon: data['service_icon'] as String? ?? 'build',
      driverName: customer?['full_name'] as String? ?? 'Unknown Customer',
      driverPhone: customer?['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      distanceMiles: 2.5,
      description: data['description'] as String? ?? '',
      postedMinutesAgo: _minutesAgo(data['created_at'] as String?),
      urgency: data['urgency'] as String? ?? 'standard',
      status: mappedStatus,
      estimatedValue: (data['quoted_price'] as num?)?.toDouble() ?? 0.0,
      quoteSent: data['quoted_price'] != null,
      driverImageUrl:
          customer?['avatar_url'] as String? ??
          'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg',
      driverImageSemanticLabel: 'Customer profile photo',
    );
  }

  _JobRequest _mapToJobRequestFromRecord(Map<String, dynamic> record) {
    final statusStr = record['job_status'] as String? ?? 'pending';
    final mappedStatus = _mapStatus(statusStr);
    final existing = _jobs.firstWhere(
      (j) => j.id == record['id'],
      orElse: () => _JobRequest(
        id: record['id'] as String? ?? '',
        serviceType: record['service_type'] as String? ?? '',
        serviceIcon: record['service_icon'] as String? ?? 'build',
        driverName: 'Customer',
        driverPhone: '',
        address: record['address'] as String? ?? '',
        distanceMiles: 2.5,
        description: record['description'] as String? ?? '',
        postedMinutesAgo: _minutesAgo(record['created_at'] as String?),
        urgency: record['urgency'] as String? ?? 'standard',
        status: mappedStatus,
        estimatedValue: (record['quoted_price'] as num?)?.toDouble() ?? 0.0,
        quoteSent: record['quoted_price'] != null,
        driverImageUrl:
            'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg',
        driverImageSemanticLabel: 'Customer profile photo',
      ),
    );

    return _JobRequest(
      id: existing.id,
      serviceType: record['service_type'] as String? ?? existing.serviceType,
      serviceIcon: record['service_icon'] as String? ?? existing.serviceIcon,
      driverName: existing.driverName,
      driverPhone: existing.driverPhone,
      address: record['address'] as String? ?? existing.address,
      distanceMiles: existing.distanceMiles,
      description: record['description'] as String? ?? existing.description,
      postedMinutesAgo: existing.postedMinutesAgo,
      urgency: record['urgency'] as String? ?? existing.urgency,
      status: mappedStatus,
      estimatedValue:
          (record['quoted_price'] as num?)?.toDouble() ??
          existing.estimatedValue,
      quoteSent: record['quoted_price'] != null,
      driverImageUrl: existing.driverImageUrl,
      driverImageSemanticLabel: existing.driverImageSemanticLabel,
    );
  }

  String _mapStatus(String dbStatus) {
    switch (dbStatus) {
      case 'quoted':
        return 'quoted';
      case 'accepted':
      case 'confirmed':
        return 'accepted';
      case 'en_route':
        return 'en_route';
      case 'in_progress':
        return 'accepted';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'new';
    }
  }

  int _minutesAgo(String? isoString) {
    if (isoString == null) return 0;
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 0;
    return DateTime.now().difference(dt).inMinutes;
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────────────

  void _onStatusFilterChanged(String status) {
    setState(() => _selectedStatusFilter = status);
  }

  void _toggleService(String id) {
    if (!_enabledServices.contains(id)) {
      final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
      if (plan != null) {
        final maxCategories = plan['max_categories'] as int? ?? 1;
        final activeCategoriesCount = _enabledServices.length;

        if (maxCategories > 0 && activeCategoriesCount >= maxCategories) {
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
              setState(() => _currentTabIndex = 2); // Switch to Plans tab
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
              content: Text('${l.t('pricing_saved_for')} $displayName'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }

  void _saveServices() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSavingServices = true);
    final l = LocalizationService.instance;

    try {
      final List<Map<String, dynamic>> servicesToSave = [];
      for (final id in _enabledServices) {
        final pricing = _pricingMap[id]!;
        servicesToSave.add({
          'category_id': int.tryParse(id),
          'base_price': pricing.basePrice,
          'distance_rules': pricing.distanceRules.map((r) => {
            'from': r.fromMiles,
            'to': r.toMiles,
            'fee': r.extraFee,
          }).toList(),
          'time_surcharges': pricing.timeSurcharges.map((s) => {
            'label': s.label,
            'start': s.startHour,
            'end': s.endHour,
            'amount': s.amount,
            'is_percent': s.isPercent,
          }).toList(),
        });
      }

      await SupabaseService.instance.saveProviderServices(userId, servicesToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('all_saved_success')),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save services'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingServices = false);
    }
  }

  void _onSendQuote(_JobRequest job) {
    final l = LocalizationService.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuoteBottomSheetWidget(
        job: job,
        onQuoteSubmitted: (price, eta, paymentMethods) async {
          Navigator.pop(ctx);
          try {
            await SupabaseService.instance.sendQuote(
              requestId: job.id,
              price: price,
              etaMinutes: eta,
              paymentMethods: paymentMethods,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Quote of \$$price sent! ETA: $eta min'),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.t('generic_error')),
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signUpLoginScreen,
        (r) => false,
      );
    }
  }

  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final l = LocalizationService.instance;
    try {
      // Upsert into provider_subscriptions
      await Supabase.instance.client.from('provider_subscriptions').upsert({
        'provider_id': userId,
        'plan_id': plan['id'],
        'status': 'active',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'provider_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to ${plan['name']}'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Reload all data to apply new restrictions
      await _initData();
    } catch (e) {
      debugPrint('Subscribe error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('generic_error')),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

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
          icon: const Icon(Icons.logout_rounded),
          onPressed: _signOut,
          tooltip: l.t('sign_out'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('job_requests'),
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              l.t('provider_dashboard'),
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppTheme.onSurface,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            color: AppTheme.primary,
            tooltip: l.t('my_profile'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.providerProfileScreen),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.serviceRequestScreen,
                (r) => false,
              ),
              icon: const Icon(Icons.directions_car_outlined, size: 15),
              label: Text(
                'Driver View',
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ProviderStatsHeaderWidget(jobs: _jobs),
            _buildTabSelector(l),
            Expanded(
              child: _buildTabContent(l),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentTabIndex == 0 
        ? FloatingActionButton.extended(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.t('select_job_detail')),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.onSurface,
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(l.t('send_quote'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700)),
          )
        : _currentTabIndex == 1 
          ? FloatingActionButton.extended(
              onPressed: _isSavingServices ? null : _saveServices,
              backgroundColor: AppTheme.primary,
              icon: _isSavingServices 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(l.t('save_all'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildTabSelector(LocalizationService l) {
    final tabs = [
      {'label': l.t('job_requests'), 'icon': Icons.work_outline_rounded},
      {'label': l.t('my_services_pricing'), 'icon': Icons.build_circle_outlined},
      {'label': l.t('subscription_plans'), 'icon': Icons.card_membership_rounded},
    ];

    return Container(
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _currentTabIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _currentTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? null : Border.all(color: AppTheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(tabs[index]['icon'] as IconData, 
                         size: 16, 
                         color: isSelected ? Colors.white : AppTheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      tabs[index]['label'] as String,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(LocalizationService l) {
    switch (_currentTabIndex) {
      case 0:
        return _buildJobRequestsTab(l);
      case 1:
        return _buildServicesTab(l);
      case 2:
        return _buildPlansTab(l);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildJobRequestsTab(LocalizationService l) {
    return Column(
      children: [
        _StatusFilterBar(
          selectedStatus: _selectedStatusFilter,
          onStatusChanged: _onStatusFilterChanged,
        ),
        Expanded(
          child: _isLoading
              ? const JobListSkeletonWidget()
              : _filteredJobs.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.work_off_outlined,
                  title: l.t('no_job_requests'),
                  description: l.t('new_jobs_info'),
                  ctaLabel: l.t('update_services'),
                  onCta: () => setState(() => _currentTabIndex = 1),
                )
              : RefreshIndicator(
                  onRefresh: _loadJobs,
                  color: AppTheme.primary,
                  child: _buildJobList(),
                ),
        ),
      ],
    );
  }

  Widget _buildServicesTab(LocalizationService l) {
    if (_isLoadingCategories) return const Center(child: CircularProgressIndicator());

    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final int maxCats = plan?['max_categories'] as int? ?? 1;
    final String usageText = maxCats == 0 
        ? 'Unlimited categories' 
        : '${_enabledServices.length} / $maxCats categories used';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select services you provide and configure your pricing rules.',
                    style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_enabledServices.length >= maxCats && maxCats != 0)
                        ? AppTheme.errorContainer
                        : AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    usageText,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: (_enabledServices.length >= maxCats && maxCats != 0) ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
            ),
            itemCount: _allServices.length,
            itemBuilder: (context, index) {
              final service = _allServices[index];
              final id = service['id'].toString();
              return _ServiceToggleCard(
                service: service,
                isEnabled: _enabledServices.contains(id),
                onToggle: () => _toggleService(id),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_enabledServices.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.t('pricing_configuration'), style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            ...(_enabledServices.map((id) {
              final service = _allServices.firstWhere((s) => s['id'].toString() == id);
              return _ServicePricingCard(
                service: service,
                pricing: _pricingMap[id] ?? const _ServicePricing(basePrice: 0),
                onEdit: () => _openPricingEditor(service),
              );
            }).toList()),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }

  Widget _buildPlansTab(LocalizationService l) {
    if (_isLoadingPlans) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _buildBillingToggle('monthly', l.t('per_month').replaceAll('/', '')),
                _buildBillingToggle('yearly', '${l.t('per_year').replaceAll('/', '')} (Save 20%)'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._availablePlans.asMap().entries.map((e) => _buildPlanCard(e.value, e.key, l)),
          const SizedBox(height: 40),
        ],
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
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          )),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, LocalizationService l) {
    final bool isFeatured = plan['is_featured'] as bool? ?? false;
    final String badgeText = plan['badge_text'] as String? ?? '';
    final bool isCurrentPlan = _activeSubscription != null && _activeSubscription!['plan_id'] == plan['id'];
    final isPopular = isFeatured || index == 1 || badgeText.isNotEmpty || isCurrentPlan;

    final priceMonthly = (plan['price_monthly'] as num?)?.toDouble() ?? 0;
    final priceYearly = (plan['price_yearly'] as num?)?.toDouble();
    final displayPrice = _billingCycle == 'yearly' && priceYearly != null ? priceYearly / 12 : priceMonthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan ? Colors.blue : (isPopular ? AppTheme.primary : AppTheme.outlineVariant),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (isCurrentPlan || isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentPlan ? Colors.blue : AppTheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Text(
                isCurrentPlan ? l.t('current_plan') : (badgeText.isNotEmpty ? badgeText : l.t('most_popular')),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.translateContent(plan['name_translations'] as Map<String, dynamic>? ?? {}, fallbackText: plan['name']),
                         style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('\$${displayPrice.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : () => _subscribeToPlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan ? Colors.blue.withAlpha(20) : AppTheme.primary,
                      foregroundColor: isCurrentPlan ? Colors.blue : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isCurrentPlan ? l.t('current_plan') : l.t('subscribe')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filteredJobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _filteredJobs[index];
        return _AnimatedJobCard(
          key: ValueKey(job.id),
          job: job,
          delay: Duration(milliseconds: 50 * index),
          listController: _listController,
          onSendQuote: () => _onSendQuote(job),
          onStatusChanged: _loadJobs,
        );
      },
    );
  }
}

// ─── INTERNAL WIDGETS ────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const _StatusFilterBar({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = ['all', 'new', 'quoted', 'accepted', 'completed'];
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = selectedStatus == filters[i];
          return ChoiceChip(
            label: Text(filters[i].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            selected: isSelected,
            onSelected: (_) => onStatusChanged(filters[i]),
            selectedColor: AppTheme.primaryContainer,
            labelStyle: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.muted),
          );
        },
      ),
    );
  }
}

class _AnimatedJobCard extends StatefulWidget {
  final _JobRequest job;
  final Duration delay;
  final AnimationController listController;
  final VoidCallback onSendQuote;
  final VoidCallback? onStatusChanged;

  const _AnimatedJobCard({
    super.key,
    required this.job,
    required this.delay,
    required this.listController,
    required this.onSendQuote,
    this.onStatusChanged,
  });

  @override
  State<_AnimatedJobCard> createState() => _AnimatedJobCardState();
}

class _AnimatedJobCardState extends State<_AnimatedJobCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<double>(begin: 24, end: 0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        );
      },
      child: JobRequestCardWidget(
        job: JobRequest(
          id: widget.job.id, serviceType: widget.job.serviceType, serviceIcon: widget.job.serviceIcon,
          urgency: widget.job.urgency, driverName: widget.job.driverName, driverImageUrl: widget.job.driverImageUrl,
          driverImageSemanticLabel: widget.job.driverImageSemanticLabel, address: widget.job.address,
          distanceMiles: widget.job.distanceMiles, description: widget.job.description,
          estimatedValue: widget.job.estimatedValue, status: widget.job.status,
          quoteSent: widget.job.quoteSent, postedMinutesAgo: widget.job.postedMinutesAgo,
        ),
        onSendQuote: widget.onSendQuote,
        onStatusChanged: widget.onStatusChanged,
      ),
    );
  }
}

class _ServiceToggleCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _ServiceToggleCard({required this.service, required this.isEnabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final String name = (service['name_translations'] as Map?)?[l.currentLanguageCode] ?? service['name'] ?? '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isEnabled ? AppTheme.primary : AppTheme.outlineVariant, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: isEnabled ? AppTheme.primary.withAlpha(30) : AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                ),
                if (isEnabled) const Icon(Icons.check_circle, size: 20, color: AppTheme.primary),
              ],
            ),
            Text(name, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: isEnabled ? AppTheme.primary : AppTheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _ServicePricingCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final _ServicePricing pricing;
  final VoidCallback onEdit;

  const _ServicePricingCard({required this.service, required this.pricing, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final hasPrice = pricing.basePrice > 0;
    final String name = (service['name_translations'] as Map?)?[l.currentLanguageCode] ?? service['name'] ?? '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.outlineVariant)),
      child: Row(
        children: [
          Text(iconEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(hasPrice ? 'Base: \$${pricing.basePrice.toStringAsFixed(0)}' : 'Price not set', 
                   style: GoogleFonts.manrope(fontSize: 12, color: hasPrice ? AppTheme.success : AppTheme.warning)),
            ]),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary)),
        ],
      ),
    );
  }
}

// ─── PRICING EDITOR (Copied from separate screen) ───────────────────────────

class _PricingEditorSheet extends StatefulWidget {
  final Map<String, dynamic> service;
  final _ServicePricing pricing;
  final bool canSetDistance;
  final bool canUseAfterHours;
  final void Function(_ServicePricing) onSave;

  const _PricingEditorSheet({required this.service, required this.pricing, required this.canSetDistance, required this.canUseAfterHours, required this.onSave});

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
    _basePriceCtrl = TextEditingController(text: widget.pricing.basePrice > 0 ? widget.pricing.basePrice.toStringAsFixed(0) : '');
    _distanceRules = List.from(widget.pricing.distanceRules);
    _timeSurcharges = List.from(widget.pricing.timeSurcharges);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2))),
            TextField(controller: _basePriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Price (\$)', hintText: '85')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => widget.onSave(_ServicePricing(basePrice: double.tryParse(_basePriceCtrl.text) ?? 0, distanceRules: _distanceRules, timeSurcharges: _timeSurcharges)),
              child: const Text('Save Pricing'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MODELS ──────────────────────────────────────────────────────────────────

class _JobRequest {
  final String id, serviceType, serviceIcon, driverName, driverPhone, address, description, urgency, status, driverImageUrl, driverImageSemanticLabel;
  final double distanceMiles, estimatedValue;
  final bool quoteSent;
  final int postedMinutesAgo;

  _JobRequest({required this.id, required this.serviceType, required this.serviceIcon, required this.driverName, required this.driverPhone, required this.address, required this.distanceMiles, required this.description, required this.postedMinutesAgo, required this.urgency, required this.status, required this.estimatedValue, required this.quoteSent, required this.driverImageUrl, required this.driverImageSemanticLabel});
}

class _ServicePricing {
  final double basePrice;
  final List<_DistanceRule> distanceRules;
  final List<_TimeSurcharge> timeSurcharges;
  const _ServicePricing({required this.basePrice, this.distanceRules = const [], this.timeSurcharges = const []});
}

class _DistanceRule {
  final double fromMiles;
  final double? toMiles;
  final double extraFee;
  const _DistanceRule({required this.fromMiles, this.toMiles, required this.extraFee});
}

class _TimeSurcharge {
  final String label;
  final int startHour, endHour;
  final double amount;
  final bool isPercent;
  const _TimeSurcharge({required this.label, required this.startHour, required this.endHour, required this.amount, required this.isPercent});
}
