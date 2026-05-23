import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../../config/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import '../../widgets/service_area_map_widget.dart';
import './widgets/job_request_card_widget.dart';
import './widgets/provider_stats_header_widget.dart';
import './widgets/quote_bottom_sheet_widget.dart';

class JobRequestsScreen extends StatefulWidget {
  final int? initialTabIndex;
  
  const JobRequestsScreen({super.key, this.initialTabIndex});

  @override
  State<JobRequestsScreen> createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedStatusFilter = 'new';
  late int _currentTabIndex;

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
  Color _dynamicCurrentPlanColor = Colors.blue;
  bool _isSubscribing = false;

  // Range State
  String _distanceUnit = 'mi';
  double _serviceRange = AppConstants.defaultServiceRangeMiles;
  bool _isSavingRange = false;
  double? _providerLat;
  double? _providerLng;

  // Profile
  String _providerName = '';
  String _locationLabel = '';
  bool _showRoleSwitcher = true;

  List<_JobRequest> get _filteredJobs {
    return _jobs.where((job) {
      if (_selectedStatusFilter == 'active') {
        // ONLY show ongoing jobs (accepted and further)
        return job.status == 'accepted' ||
            job.status == 'en_route' ||
            job.status == 'awaiting_confirmation' ||
            job.status == 'awaiting_reconfirmation' ||
            job.status == 'disputed';
      }
      // 'new', 'quoted', 'completed' will match their specific mapped strings
      return job.status == _selectedStatusFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex ?? 0;
    _isSavingServices = false; // Reset in case it was stuck
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initData();
    _subscribeToJobUpdates();
  }

  Future<void> _initData() async {
    // 1. Load critical dependency data first
    await Future.wait([
      _loadCategories(),
      _loadProviderServices(),
      _loadSubscription(),
      _loadPlans(),
      _loadProviderRange(),
      _loadProviderProfile(),
      _loadRoleSwitcherSetting(),
    ]);

    // 2. ONLY then load jobs using the now-populated enabled categories
    await _loadJobs();
  }

  @override
  void dispose() {
    _listController.dispose();
    _jobSubscription?.unsubscribe();
    super.dispose();
  }

  // ─── DATA LOADING ──────────────────────────────────────────────────────────

  Future<void> _loadJobs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Filter jobs by enabled categories
      final activeCategoryNames = _enabledServices.map((id) {
        final cat = _allServices.firstWhere((s) => s['id'].toString() == id);
        return cat['name'] as String;
      }).toList();

      final data = await SupabaseService.instance.getProviderJobRequests(
        categories: activeCategoryNames,
      );
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
    if (!mounted) return;
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
          // Use free plan defaults from constants
          _activeSubscription = {
            'plan': AppConstants.freePlanLimits,
          };
        }
      });
    }
  }

  Future<void> _loadProviderServices() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    debugPrint('Loading provider services for user: $userId');
    final configs = await SupabaseService.instance.getProviderServices(userId);
    debugPrint('Loaded ${configs.length} provider service configs: $configs');
    
    if (mounted) {
      setState(() {
        // Clear and reload everything from database to ensure fresh data
        _enabledServices.clear();
        _pricingMap.clear();
        
        for (final config in configs) {
          final id = config['category_id'].toString();
          _enabledServices.add(id);
          debugPrint('Enabled service: $id');

          final distanceRules = (config['distance_rules'] as List?)
                  ?.map(
                    (r) => _DistanceRule(
                      fromMiles: (r['from'] as num).toDouble(),
                      toMiles: r['to'] != null ? (r['to'] as num).toDouble() : null,
                      extraFee: (r['fee'] as num).toDouble(),
                    ),
                  )
                  .toList() ??
              [];

          final timeSurcharges = (config['time_surcharges'] as List?)
                  ?.map(
                    (s) => _TimeSurcharge(
                      label: s['label'] ?? '',
                      startHour: s['start'] as int,
                      endHour: s['end'] as int,
                      amount: (s['amount'] as num).toDouble(),
                      isPercent: s['is_percent'] as bool,
                    ),
                  )
                  .toList() ??
              [];

          _pricingMap[id] = _ServicePricing(
            basePrice: (config['base_price'] as num).toDouble(),
            distanceRules: distanceRules,
            timeSurcharges: timeSurcharges,
            supportedVehicleSizes: List<String>.from(config['supported_vehicle_sizes'] ?? []),
          );
          debugPrint('Loaded pricing for service $id: ${_pricingMap[id]?.basePrice}');
        }
        debugPrint('Total enabled services: ${_enabledServices.length}');
      });
    }
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() => _isLoadingPlans = true);
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price_monthly', ascending: true);

      // Also fetch dynamic highlight color & unit
      final settingsRes = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', [
            'current_plan_highlight_color',
            'distance_unit',
          ]);

      if (mounted) {
        setState(() {
          _availablePlans = List<Map<String, dynamic>>.from(response);

          for (final row in settingsRes) {
            if (row['setting_key'] == 'current_plan_highlight_color') {
              try {
                final hex = (row['setting_value'] as String).replaceFirst(
                  '#',
                  '',
                );
                _dynamicCurrentPlanColor = Color(
                  int.parse('FF$hex', radix: 16),
                );
              } catch (_) {}
            } else if (row['setting_key'] == 'distance_unit') {
              _distanceUnit = row['setting_value'] ?? 'mi';
            }
          }

          _isLoadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _loadProviderRange() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select('service_range_miles, address_lat, address_lng')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _serviceRange =
              (res['service_range_miles'] as num?)?.toDouble() ?? AppConstants.defaultServiceRangeMiles;
          _providerLat = (res['address_lat'] as num?)?.toDouble();
          _providerLng = (res['address_lng'] as num?)?.toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRoleSwitcherSetting() async {
    final val = await SupabaseService.instance.getAppSetting('show_role_switcher');
    if (mounted) setState(() => _showRoleSwitcher = val != 'false');
  }

  Future<void> _loadProviderProfile() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, address, selected_city_id, selected_state_id')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && mounted) {
        final cityId = res['selected_city_id'] as String?;
        final stateId = res['selected_state_id'] as String?;
        String location = '';
        if (cityId != null) {
          final cityRes = await Supabase.instance.client
              .from('cities')
              .select('name')
              .eq('id', cityId)
              .maybeSingle();
          final cityName = cityRes?['name'] as String? ?? '';
          if (stateId != null) {
            final stateRes = await Supabase.instance.client
                .from('states')
                .select('code')
                .eq('id', stateId)
                .maybeSingle();
            final stateCode = stateRes?['code'] as String? ?? '';
            location = stateCode.isNotEmpty ? '$cityName, $stateCode' : cityName;
          } else {
            location = cityName;
          }
        }
        if (mounted) {
          setState(() {
            _providerName = res['full_name'] as String? ?? '';
            _locationLabel = location;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading provider profile: $e');
    }
  }

  Future<void> _saveServiceRange(double value) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSavingRange = true);
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'service_range_miles': value.toInt()})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service range updated successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update range'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRange = false);
    }
  }

  Future<void> _updateProviderLocation(double lat, double lng) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.instance.updateProviderGeoZone(
        providerId: userId,
        addressLat: lat,
        addressLng: lng,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update location'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── SUBSCRIPTION & REALTIME ──────────────────────────────────────────────

  void _subscribeToJobUpdates() {
    _jobSubscription = SupabaseService.instance.subscribeToJobRequestUpdates((
      record,
    ) {
      if (!mounted) return;

      final String id = record['id']?.toString() ?? '';
      if (id.isEmpty) return;

      // 1. Find existing job to handle partial payloads (REPLICA IDENTITY DEFAULT)
      final existingIdx = _jobs.indexWhere((j) => j.id == id);
      final String serviceType = record['service_type'] as String? ?? 
                                (existingIdx != -1 ? _jobs[existingIdx].serviceType : '');
      
      final String providerId = record['provider_id']?.toString() ?? 
                               (existingIdx != -1 ? _jobs[existingIdx].providerId ?? '' : '');

      // 2. Filter by enabled categories
      final activeCategoryNames = _enabledServices.map((id) {
        final cat = _allServices.firstWhere((s) => s['id'].toString() == id);
        return cat['name'] as String;
      }).toList();

      final bool isMyJob = providerId == SupabaseService.instance.currentUser?.id;
      final bool supportsCategory = activeCategoryNames.contains(serviceType);

      // ONLY process if we support the category OR it is already assigned to us
      if (!supportsCategory && !isMyJob) {
        return;
      }

      // 3. Map and Update
      final updatedJob = _mapToJobRequestFromRecord(record);
      setState(() {
        if (existingIdx != -1) {
          _jobs[existingIdx] = updatedJob;
        } else {
          // New job incoming, silent reload to get full details
          SupabaseService.instance.getProviderJobRequests(
            categories: activeCategoryNames.isNotEmpty ? activeCategoryNames : null,
          ).then((data) {
            if (mounted) {
              setState(() {
                _jobs = data.map(_mapToJobRequest).toList();
              });
            }
          });
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
      providerId: data['provider_id'] as String?,
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
      driverImageUrl: (customer?['avatar_url'] as String? ?? '').isNotEmpty
          ? customer!['avatar_url']
          : 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg',
      driverImageSemanticLabel: 'Customer profile photo',
      customerConfirmation: data['customer_confirmation'] as bool?,
      providerConfirmation: data['provider_confirmation'] as bool?,
      confirmationRound: (data['confirmation_round'] as num?)?.toInt() ?? 0,
    );
  }

  _JobRequest _mapToJobRequestFromRecord(Map<String, dynamic> record) {
    final statusStr = record['job_status'] as String? ?? 'pending';
    final mappedStatus = _mapStatus(statusStr);
    final existingIdx = _jobs.indexWhere((j) => j.id == record['id']);
    
    final existing = existingIdx != -1 ? _jobs[existingIdx] : _JobRequest(
        id: record['id'] as String? ?? '',
        providerId: record['provider_id'] as String?,
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
        customerConfirmation: record['customer_confirmation'] as bool?,
        providerConfirmation: record['provider_confirmation'] as bool?,
        confirmationRound: (record['confirmation_round'] as num?)?.toInt() ?? 0,
      );

    return _JobRequest(
      id: existing.id,
      providerId: record['provider_id'] as String? ?? existing.providerId,
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
      driverImageUrl: (record['avatar_url'] as String? ?? '').isNotEmpty
          ? record['avatar_url']
          : existing.driverImageUrl,
      driverImageSemanticLabel: existing.driverImageSemanticLabel,
      customerConfirmation: record['customer_confirmation'] as bool? ?? existing.customerConfirmation,
      providerConfirmation: record['provider_confirmation'] as bool? ?? existing.providerConfirmation,
      confirmationRound: (record['confirmation_round'] as num?)?.toInt() ?? existing.confirmationRound,
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
      case 'awaiting_confirmation':
        return 'awaiting_confirmation';
      case 'awaiting_reconfirmation':
        return 'awaiting_reconfirmation';
      case 'disputed':
        return 'disputed';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'new';
    }
  }

  int _minutesAgo(String? isoString) {
    if (isoString == null) {
      return 0;
    }
    final dt = DateTime.tryParse(isoString);
    if (dt == null) {
      return 0;
    }
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
        // Initialize pricing if not exists
        if (!_pricingMap.containsKey(id) || _pricingMap[id] == null) {
          _pricingMap[id] = const _ServicePricing(basePrice: 0);
        }
      }
    });
    
    // Auto-save to database after toggling
    _saveServices();
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
        content: Text(
          'Your current plan limits you to $limit $type. Upgrade your plan to add more.',
        ),
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
    final canSetDistance =
        plan?['can_set_distance_surcharges'] as bool? ?? false;
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
        onSave: (updated) async {
          debugPrint('=== onSave callback called ===');
          debugPrint('Updated pricing: ${updated.basePrice}');
          
          // Update local map
          _pricingMap[id] = updated;
          
          // Pop the bottom sheet immediately
          Navigator.pop(ctx);
          
          // Save ALL enabled services to database (not just this one)
          // to avoid deleting other services
          _saveServices();
        },
      ),
    );
  }

  void _saveServices() async {
    debugPrint('=== _saveServices called ===');
    final userId = SupabaseService.instance.currentUser?.id;
    debugPrint('User ID: $userId');
    if (userId == null) {
      debugPrint('ERROR: No user ID, returning early');
      return;
    }

    // Note: We don't check mounted here - the database save should happen
    // even if widget is disposed

    if (mounted) {
      setState(() => _isSavingServices = true);
    }
    final l = LocalizationService.instance;

    try {
      final List<Map<String, dynamic>> servicesToSave = [];
      debugPrint('Saving ${_enabledServices.length} enabled services');
      
      if (_enabledServices.isEmpty) {
        debugPrint('WARNING: No enabled services to save');
      }
      
      for (final id in _enabledServices) {
        final pricing = _pricingMap[id];
        if (pricing == null) {
          debugPrint('ERROR: No pricing found for service $id');
          continue;
        }
        debugPrint('Adding service $id to save list');
        servicesToSave.add({
          'category_id': int.tryParse(id),
          'base_price': pricing.basePrice,
          'supported_vehicle_sizes': pricing.supportedVehicleSizes,
          'distance_rules': pricing.distanceRules
              .map(
                (r) => {
                  'from': r.fromMiles,
                  'to': r.toMiles,
                  'fee': r.extraFee,
                },
              )
              .toList(),
          'time_surcharges': pricing.timeSurcharges
              .map(
                (s) => {
                  'label': s.label,
                  'start': s.startHour,
                  'end': s.endHour,
                  'amount': s.amount,
                  'is_percent': s.isPercent,
                },
              )
              .toList(),
        });
      }

      debugPrint('Services to save: $servicesToSave');
      
      if (servicesToSave.isEmpty) {
        debugPrint('WARNING: servicesToSave is empty, nothing to save');
      }
      
      await SupabaseService.instance.saveProviderServices(
        userId,
        servicesToSave,
      );
      debugPrint('Services saved successfully');

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
    } catch (e, stackTrace) {
      debugPrint('ERROR in _saveServices: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save services: $e'),
            backgroundColor: AppTheme.error,
          ),
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
            
            // Immediate local refresh for zero-latency feedback
            await _loadJobs();

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

    setState(() => _isSubscribing = true);
    try {
      final planId = plan['id'];
      debugPrint('Attempting subscription for user $userId to plan $planId');

      // 0. Ensure user profile exists first (fixes foreign key constraint)
      final profileCreated = await SupabaseService.instance.ensureUserProfile(userId);
      if (!profileCreated) {
        throw Exception('Failed to create user profile - cannot subscribe');
      }

      // 1. Simple Upsert (minimal fields to avoid validation errors)
      await Supabase.instance.client.from('provider_subscriptions').upsert({
        'provider_id': userId,
        'plan_id': planId,
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'provider_id');

      debugPrint('Subscription database write successful');

      // 2. Reload all data to apply new restrictions and refresh highlight
      await _initData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to ${plan['name']}'),
            backgroundColor: _dynamicCurrentPlanColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Detailed Subscribe Error: $e');
      if (mounted) {
        // Show the actual technical error to help identify the DB issue
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: SingleChildScrollView(child: Text(e.toString())),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.t('job_requests'),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l.t('provider_dashboard'),
              style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 20),
            color: AppTheme.onSurface,
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 20),
            color: AppTheme.primary,
            tooltip: l.t('my_profile'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.providerProfileScreen),
            visualDensity: VisualDensity.compact,
          ),
          if (_showRoleSwitcher)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.serviceRequestScreen,
                (r) => false,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Driver',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ProviderStatsHeaderWidget(
              jobs: _jobs,
              selectedStatus: _selectedStatusFilter,
              onStatusChanged: _onStatusFilterChanged,
              providerName: _providerName,
              locationLabel: _locationLabel,
            ),
            _buildTabSelector(l),
            Expanded(child: _buildTabContent(l)),
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
              label: Text(
                l.t('send_quote'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,  // No FAB for Services tab - auto-save handles everything
    );
  }

  Widget _buildTabSelector(LocalizationService l) {
    final tabs = [
      {'label': l.t('job_requests'), 'icon': Icons.work_outline_rounded},
      {
        'label': l.t('my_services_pricing'),
        'icon': Icons.build_circle_outlined,
      },
      {
        'label': l.t('subscription_plans'),
        'icon': Icons.card_membership_rounded,
      },
    ];

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.surfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: AppTheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[index]['label'] as String,
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
    if (_isLoading) return const JobListSkeletonWidget();

    return Column(
      children: [
        _buildCompletedFilter(l),
        Expanded(
          child: _filteredJobs.isEmpty
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

  Widget _buildCompletedFilter(LocalizationService l) {
    final isSelected = _selectedStatusFilter == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: ChoiceChip(
        label: const Text(
          'COMPLETED',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _selectedStatusFilter = val ? 'completed' : 'new');
        },
        selectedColor: AppTheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.muted,
        ),
      ),
    );
  }

  Widget _buildServicesTab(LocalizationService l) {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final int maxCats = plan?['max_categories'] as int? ?? 1;
    final String usageText = maxCats == 0
        ? 'Unlimited categories'
        : '${_enabledServices.length} / $maxCats categories used';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRangeCard(l),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select services you provide and configure your pricing rules.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                      color:
                          (_enabledServices.length >= maxCats && maxCats != 0)
                          ? AppTheme.error
                          : AppTheme.primary,
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
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
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
              child: Text(
                l.t('pricing_configuration'),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...(_enabledServices.map((id) {
              final service = _allServices.firstWhere(
                (s) => s['id'].toString() == id,
              );
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

  Widget _buildRangeCard(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                l.t('service_range'),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isSavingRange)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Map showing service area
          if (_providerLat != null && _providerLng != null)
            ServiceAreaMapWidget(
              latitude: _providerLat!,
              longitude: _providerLng!,
              serviceRange: _serviceRange,
              distanceUnit: _distanceUnit,
              onRangeChanged: (v) => setState(() => _serviceRange = v),
              onRangeChangeEnd: _saveServiceRange,
              onLocationChanged: (lat, lng) {
                setState(() {
                  _providerLat = lat;
                  _providerLng = lng;
                });
                // Save new location to profile
                _updateProviderLocation(lat, lng);
              },
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 48, color: AppTheme.muted),
                    const SizedBox(height: 12),
                    Text(
                      'Set your location in Profile',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Go to Profile > Personal Info > Coordinates',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlansTab(LocalizationService l) {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
          ..._availablePlans.asMap().entries.map(
            (e) => _buildPlanCard(e.value, e.key, l),
          ),
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
    final bool isFeatured = plan['is_featured'] as bool? ?? false;
    final String badgeText = plan['badge_text'] as String? ?? '';
    final bool isCurrentPlan =
        _activeSubscription != null &&
        _activeSubscription!['plan_id'] == plan['id'];
    final isPopular =
        isFeatured || index == 1 || badgeText.isNotEmpty || isCurrentPlan;

    final priceMonthly = (plan['price_monthly'] as num?)?.toDouble() ?? 0;
    final priceYearly = (plan['price_yearly'] as num?)?.toDouble();
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
              ? _dynamicCurrentPlanColor
              : (isPopular ? AppTheme.primary : AppTheme.outlineVariant),
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
                color: isCurrentPlan
                    ? _dynamicCurrentPlanColor
                    : AppTheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.translateContent(
                        plan['name_translations'] as Map<String, dynamic>? ??
                            {},
                        fallbackText: plan['name'],
                      ),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\$${displayPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isCurrentPlan || _isSubscribing)
                        ? null
                        : () => _subscribeToPlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? _dynamicCurrentPlanColor.withAlpha(20)
                          : AppTheme.primary,
                      foregroundColor: isCurrentPlan
                          ? _dynamicCurrentPlanColor
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubscribing && !isCurrentPlan
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isCurrentPlan
                                ? l.t('current_plan')
                                : l.t('subscribe'),
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

  Widget _buildJobList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
    _slideAnim = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
          id: widget.job.id,
          serviceType: widget.job.serviceType,
          serviceIcon: widget.job.serviceIcon,
          urgency: widget.job.urgency,
          driverName: widget.job.driverName,
          driverImageUrl: widget.job.driverImageUrl,
          driverImageSemanticLabel: widget.job.driverImageSemanticLabel,
          address: widget.job.address,
          distanceMiles: widget.job.distanceMiles,
          description: widget.job.description,
          estimatedValue: widget.job.estimatedValue,
          status: widget.job.status,
          quoteSent: widget.job.quoteSent,
          postedMinutesAgo: widget.job.postedMinutesAgo,
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

  const _ServiceToggleCard({
    required this.service,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final String name =
        (service['name_translations'] as Map?)?[l.currentLanguageCode] ??
        service['name'] ??
        '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled ? AppTheme.primary : AppTheme.outlineVariant,
            width: 2,
          ),
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
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppTheme.primary.withAlpha(30)
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                ),
                if (isEnabled)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppTheme.primary,
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
            ),
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

  const _ServicePricingCard({
    required this.service,
    required this.pricing,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final hasPrice = pricing.basePrice > 0;
    final String name =
        (service['name_translations'] as Map?)?[l.currentLanguageCode] ??
        service['name'] ??
        '';
    final String iconEmoji = service['icon_emoji'] ?? '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Text(iconEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hasPrice
                      ? 'Base: \$${pricing.basePrice.toStringAsFixed(0)}'
                      : 'Price not set',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: hasPrice ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
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
  late List<String> _supportedVehicles;

  // Use shared vehicle size options from AppConstants
  List<Map<String, dynamic>> get _vehicleSizeOptions => AppConstants.vehicleSizeOptions;

  @override
  void initState() {
    super.initState();
    debugPrint('PricingEditorSheet initState - initial price: ${widget.pricing.basePrice}');
    _basePriceCtrl = TextEditingController(
      text: widget.pricing.basePrice > 0
          ? widget.pricing.basePrice.toStringAsFixed(0)
          : '',
    );
    _distanceRules = List.from(widget.pricing.distanceRules);
    _timeSurcharges = List.from(widget.pricing.timeSurcharges);
    _supportedVehicles = List.from(widget.pricing.supportedVehicleSizes);
  }

  @override
  void dispose() {
    debugPrint('PricingEditorSheet dispose - final price: ${_basePriceCtrl.text}');
    _basePriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final String serviceName = l.translateContent(
      widget.service['name_translations'] as Map<String, dynamic>? ?? {},
      fallbackText: widget.service['name'] as String? ?? '',
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '${l.t('pricing')} - $serviceName',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            _buildBasePriceField(),
            const SizedBox(height: 20),
            _buildVehicleSelectionSection(l),
            const SizedBox(height: 20),
            if (widget.canSetDistance) _buildDistanceSection(l),
            if (widget.canUseAfterHours) _buildAfterHoursSection(l),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  debugPrint('=== PRICING EDITOR SAVE CLICKED ===');
                  debugPrint('Base price: ${_basePriceCtrl.text}');
                  debugPrint('Distance rules: ${_distanceRules.length}');
                  debugPrint('Time surcharges: ${_timeSurcharges.length}');
                  debugPrint('Supported vehicles: ${_supportedVehicles.length}');
                  widget.onSave(
                    _ServicePricing(
                      basePrice: double.tryParse(_basePriceCtrl.text) ?? 0,
                      distanceRules: _distanceRules,
                      timeSurcharges: _timeSurcharges,
                      supportedVehicleSizes: _supportedVehicles,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.t('save'),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasePriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base Service Price',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _basePriceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: 'e.g. 85',
            filled: true,
            fillColor: AppTheme.surfaceVariant.withAlpha(50),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelectionSection(LocalizationService l) {
    // Handle both List and JSON String formats from database
    final dynamic rawSizes = widget.service['vehicle_sizes'];
    List<dynamic> allowedSizes = [];
    if (rawSizes is List) {
      allowedSizes = rawSizes;
    } else if (rawSizes is String) {
      try {
        allowedSizes = json.decode(rawSizes) as List;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supported Vehicles',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the vehicle types you can assist with for this service.',
          style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vehicleSizeOptions.map((opt) {
            final isAllowedByAdmin = allowedSizes.contains(opt['id']);
            final isSelected = _supportedVehicles.contains(opt['id']);

            // If not allowed by admin, don't even show it (or show disabled)
            if (!isAllowedByAdmin) return const SizedBox.shrink();

            return InkWell(
              onTap: () {
                debugPrint('Vehicle tapped: ${opt['id']}');
                debugPrint('Current price: ${_basePriceCtrl.text}');
                setState(() {
                  if (isSelected) {
                    _supportedVehicles.remove(opt['id']);
                    debugPrint('Removed vehicle ${opt['id']}');
                  } else {
                    _supportedVehicles.add(opt['id'] as String);
                    debugPrint('Added vehicle ${opt['id']}');
                  }
                });
                debugPrint('After setState - price: ${_basePriceCtrl.text}');
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withAlpha(25)
                      : AppTheme.surfaceVariant.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.outline,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(opt['emoji'] as String,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      opt['label'] as String,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check, size: 14, color: AppTheme.primary),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDistanceSection(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            const Icon(
              Icons.add_road_outlined,
              size: 18,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Distance Surcharges',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._distanceRules.map((rule) => _buildDistanceRuleTile(rule)),
        TextButton.icon(
          onPressed: _addDistanceRule,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add distance rule'),
        ),
      ],
    );
  }

  Widget _buildDistanceRuleTile(_DistanceRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${rule.fromMiles.toInt()} - ${rule.toMiles?.toInt() ?? '+'} miles: \$${rule.extraFee.toStringAsFixed(0)} fee',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _distanceRules.remove(rule)),
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterHoursSection(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            const Icon(
              Icons.nights_stay_outlined,
              size: 18,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'After-Hours Rates',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._timeSurcharges.map((s) => _buildTimeSurchargeTile(s)),
        TextButton.icon(
          onPressed: _addTimeSurcharge,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add time rule'),
        ),
      ],
    );
  }

  Widget _buildTimeSurchargeTile(_TimeSurcharge s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${s.startHour}:00 - ${s.endHour}:00: ${s.amount}${s.isPercent ? '%' : '\$'} extra',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _timeSurcharges.remove(s)),
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  void _addDistanceRule() {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final feeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Distance Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'From Miles'),
            ),
            TextField(
              controller: toCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'To Miles (Empty for +)',
              ),
            ),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Extra Fee (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final from = double.tryParse(fromCtrl.text) ?? 0;
              final to = double.tryParse(toCtrl.text);
              final fee = double.tryParse(feeCtrl.text) ?? 0;
              setState(
                () => _distanceRules.add(
                  _DistanceRule(fromMiles: from, toMiles: to, extraFee: fee),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addTimeSurcharge() {
    final labelCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isPercent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Time Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g. Night Shift)',
                ),
              ),
              TextField(
                controller: startCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start Hour (0-23)',
                ),
              ),
              TextField(
                controller: endCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'End Hour (0-23)'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extra Amount'),
              ),
              Row(
                children: [
                  const Text('Percentage?'),
                  const Spacer(),
                  Switch(
                    value: isPercent,
                    onChanged: (v) => setDialogState(() => isPercent = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => _timeSurcharges.add(
                    _TimeSurcharge(
                      label: labelCtrl.text,
                      startHour: int.tryParse(startCtrl.text) ?? 0,
                      endHour: int.tryParse(endCtrl.text) ?? 0,
                      amount: double.tryParse(amountCtrl.text) ?? 0,
                      isPercent: isPercent,
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MODELS ──────────────────────────────────────────────────────────────────

class _JobRequest {
  final String id;
  final String? providerId;
  final String serviceType,
      serviceIcon,
      driverName,
      driverPhone,
      address,
      description,
      urgency,
      status,
      driverImageUrl,
      driverImageSemanticLabel;
  final double distanceMiles, estimatedValue;
  final bool quoteSent;
  final int postedMinutesAgo;

  final bool? customerConfirmation;
  final bool? providerConfirmation;
  final int confirmationRound;

  _JobRequest({
    required this.id,
    this.providerId,
    required this.serviceType,
    required this.serviceIcon,
    required this.driverName,
    required this.driverPhone,
    required this.address,
    required this.distanceMiles,
    required this.description,
    required this.postedMinutesAgo,
    required this.urgency,
    required this.status,
    required this.estimatedValue,
    required this.quoteSent,
    required this.driverImageUrl,
    required this.driverImageSemanticLabel,
    this.customerConfirmation,
    this.providerConfirmation,
    this.confirmationRound = 0,
  });
}

class _ServicePricing {
  final double basePrice;
  final List<_DistanceRule> distanceRules;
  final List<_TimeSurcharge> timeSurcharges;
  final List<String> supportedVehicleSizes;
  const _ServicePricing({
    required this.basePrice,
    this.distanceRules = const [],
    this.timeSurcharges = const [],
    this.supportedVehicleSizes = const [],
  });
}

class _DistanceRule {
  final double fromMiles;
  final double? toMiles;
  final double extraFee;
  const _DistanceRule({
    required this.fromMiles,
    this.toMiles,
    required this.extraFee,
  });
}

class _TimeSurcharge {
  final String label;
  final int startHour, endHour;
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
