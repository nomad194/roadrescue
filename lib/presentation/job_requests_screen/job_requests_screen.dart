import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:roadrescue_shared/config/app_constants.dart';
import '../../routes/app_routes.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/widgets/empty_state_widget.dart';
import 'package:roadrescue_shared/widgets/loading_skeleton_widget.dart';
import 'package:roadrescue_shared/widgets/service_area_map_widget.dart';
import '../provider_profile_screen/widgets/provider_plan_purchase_dialog.dart';
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
  String _subscriptionStatus = 'inactive'; // from provider_subscription_state
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
  bool _isAvailable = true;
  bool _isSavingAvailability = false;

  // Stats
  double _averageRating = 0.0;
  bool _isLoadingStats = false;

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

  double get _maxServiceRange {
    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final raw = (plan?['max_radius_miles'] as num?)?.toDouble() ?? 200.0;
    return raw.clamp(5.0, 500.0);
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
      _loadProviderStats(),
    ]);

    // Enforce service range limit after subscription and range are loaded
    if (_serviceRange > _maxServiceRange) {
      await _saveServiceRange(_maxServiceRange);
    }

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
      final data = await SupabaseService.instance.getProviderJobRequests(
        categoryIds: _enabledServices.toList(),
      );
      if (mounted) {
        final allJobs = data.map(_mapToJobRequest).toList();
        // If provider is unavailable, only show jobs already assigned to them
        final filteredJobs = _isAvailable
            ? allJobs
            : allJobs.where((j) => j.providerId == SupabaseService.instance.currentUser?.id).toList();
        setState(() {
          _jobs = filteredJobs;
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

    // Load subscription state (trial_used, status, etc.)
    final subState = await SupabaseService.instance.getProviderSubscriptionState(userId);
    if (mounted) {
      setState(() {
        _subscriptionStatus = subState['subscription_status'] as String? ?? 'inactive';
      });
    }

    // Check new provider subscriptions table first
    final providerSub = await SupabaseService.instance.getProviderActiveSubscription(userId);
    if (mounted && providerSub != null) {
      setState(() {
        _activeSubscription = providerSub;
      });
      return;
    }

    // Fall back to legacy subscription system
    final sub = await SupabaseService.instance.getActiveSubscription(userId);
    if (mounted) {
      setState(() {
        if (sub != null) {
          _activeSubscription = sub;
        } else {
          // No active subscription - will show subscription required UI
          _activeSubscription = null;
        }
      });
    }
  }

  bool get _hasActiveSubscription {
    // Check provider_subscription_state first
    if (_subscriptionStatus == 'paused' || _subscriptionStatus == 'inactive') {
      return false;
    }
    if (_subscriptionStatus == 'active' || _subscriptionStatus == 'trial') {
      return true;
    }

    if (_activeSubscription == null) return false;
    // Check if it's a provider subscription with completed payment
    if (_activeSubscription!['payment_status'] != null) {
      final isCompleted = _activeSubscription!['payment_status'] == 'completed';
      if (!isCompleted) return false;
      // Also check expiration
      final expiresAt = _activeSubscription!['expires_at'];
      if (expiresAt != null) {
        final expDate = DateTime.tryParse(expiresAt);
        if (expDate != null && expDate.isBefore(DateTime.now())) return false;
      }
      return true;
    }
    // Legacy subscription check - check if it has a plan with valid expiration
    final expiresAt = _activeSubscription!['expires_at'] ?? _activeSubscription!['current_period_end'];
    if (expiresAt != null) {
      final expDate = expiresAt is String ? DateTime.tryParse(expiresAt) : null;
      if (expDate != null && expDate.isBefore(DateTime.now())) return false;
    }
    return _activeSubscription!['plan'] != null;
  }

  bool get _isSubscriptionPaused => _subscriptionStatus == 'paused';

  void _showPlanPurchaseDialog() {
    final currentPlanId = _activeSubscription?['plan_id'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => ProviderPlanPurchaseDialog(currentPlanId: currentPlanId),
    ).then((_) => _loadSubscription());
  }

  Widget _buildSubscriptionRequiredBanner(LocalizationService l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('subscription_required'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.t('subscription_required_desc'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showPlanPurchaseDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              l.t('subscribe'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProviderServices() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    final configs = await SupabaseService.instance.getProviderServices(userId);
    if (mounted) {
      setState(() {
        // Clear and reload everything from database to ensure fresh data
        _enabledServices.clear();
        _pricingMap.clear();
        
        for (final config in configs) {
          final id = config['category_id'].toString();
          _enabledServices.add(id);
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
        }
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

  Future<void> _loadProviderProfile() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, address, selected_city_id, selected_state_id, is_available')
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
            _isAvailable = res['is_available'] as bool? ?? true;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadProviderStats() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingStats = true);
    try {
      final ratingData = await SupabaseService.instance.getProviderRating(userId);
      if (mounted) {
        setState(() {
          _averageRating = ratingData['average_rating'] as double? ?? 0.0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _saveServiceRange(double value) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final clamped = value.clamp(5.0, _maxServiceRange);
    if (mounted) setState(() => _serviceRange = clamped);

    setState(() => _isSavingRange = true);
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'service_range_miles': clamped.toInt()})
          .eq('id', userId);

      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('service_range_updated')),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('failed_update_range')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRange = false);
    }
  }

  Future<void> _toggleAvailability() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final newValue = !_isAvailable;
    setState(() => _isSavingAvailability = true);

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'is_available': newValue})
          .eq('id', userId);

      if (mounted) {
        setState(() => _isAvailable = newValue);
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? l.t('available_msg') : l.t('unavailable_msg'),
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: newValue ? AppTheme.success : AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Refresh job list so provider sees pending jobs immediately when becoming available
        _loadJobs();
      }
    } catch (_) {
      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('failed_update_availability')),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingAvailability = false);
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

      // 0. Check if provider is available - skip new jobs if unavailable
      final existingIdx = _jobs.indexWhere((j) => j.id == id);
      final bool isExistingJob = existingIdx != -1;
      if (!_isAvailable && !isExistingJob) {
        // Provider is unavailable and this is a new job - don't show it
        return;
      }

      // 1. Find existing job to handle partial payloads (REPLICA IDENTITY DEFAULT)
      final String serviceType = record['service_type'] as String? ?? 
                                (isExistingJob ? _jobs[existingIdx].serviceType : '');
      
      final String providerId = record['provider_id']?.toString() ?? 
                               (isExistingJob ? _jobs[existingIdx].providerId ?? '' : '');

      // 2. Filter by enabled categories — match service_type against all name translations
      final bool isMyJob = providerId == SupabaseService.instance.currentUser?.id;
      bool supportsCategory = false;
      for (final id in _enabledServices) {
        final cat = _allServices.firstWhere((s) => s['id'].toString() == id, orElse: () => {});
        if (cat.isEmpty) continue;
        final baseName = (cat['name'] as String? ?? '').toLowerCase();
        if (baseName == serviceType.toLowerCase()) { supportsCategory = true; break; }
        final translationsRaw = cat['name_translations'];
        if (translationsRaw is Map) {
          for (final val in translationsRaw.values) {
            if (val is String && val.toLowerCase() == serviceType.toLowerCase()) {
              supportsCategory = true;
              break;
            }
          }
        }
        if (supportsCategory) break;
      }

      // ONLY process if we support the category OR it is already assigned to us
      if (!supportsCategory && !isMyJob) {
        return;
      }

      // 3. Filter by distance if provider has coordinates
      bool withinRange = true;
      if (_providerLat != null && _providerLng != null) {
        final jobLat = (record['customer_lat'] as num?)?.toDouble();
        final jobLng = (record['customer_lng'] as num?)?.toDouble();
        if (jobLat != null && jobLng != null) {
          final distance = _calculateDistance(_providerLat!, _providerLng!, jobLat, jobLng);
          withinRange = distance <= _serviceRange;
        } else {
          // Job has no GPS coordinates - can't verify distance, exclude it
          withinRange = false;
        }
      }

      if (!withinRange && !isMyJob) {
        return;
      }

      // 4. Map and Update
      final updatedJob = _mapToJobRequestFromRecord(record);
      setState(() {
        if (existingIdx != -1) {
          _jobs[existingIdx] = updatedJob;
        } else {
          // New job incoming, silent reload to get full details
          SupabaseService.instance.getProviderJobRequests(
            categoryIds: _enabledServices.isNotEmpty ? _enabledServices.toList() : null,
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

    // Calculate actual distance from provider to customer
    double distance = 0.0;
    if (_providerLat != null && _providerLng != null) {
      final customerLat = (data['customer_lat'] as num?)?.toDouble();
      final customerLng = (data['customer_lng'] as num?)?.toDouble();
      if (customerLat != null && customerLng != null) {
        distance = _calculateDistance(_providerLat!, _providerLng!, customerLat, customerLng);
      }
    }
    // Round to nearest whole number
    distance = distance.roundToDouble();

    return _JobRequest(
      id: data['id'] as String,
      providerId: data['provider_id'] as String?,
      serviceType: data['service_type'] as String? ?? '',
      serviceIcon: data['service_icon'] as String? ?? 'build',
      driverName: customer?['full_name'] as String? ?? 'Unknown Customer',
      driverPhone: customer?['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      distanceMiles: distance,
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
    
    // Calculate actual distance from provider to customer
    double distance = 0.0;
    if (_providerLat != null && _providerLng != null) {
      final customerLat = (record['customer_lat'] as num?)?.toDouble();
      final customerLng = (record['customer_lng'] as num?)?.toDouble();
      if (customerLat != null && customerLng != null) {
        distance = _calculateDistance(_providerLat!, _providerLng!, customerLat, customerLng);
      }
    }
    // Round to nearest whole number
    distance = distance.roundToDouble();

    final existing = existingIdx != -1 ? _jobs[existingIdx] : _JobRequest(
        id: record['id'] as String? ?? '',
        providerId: record['provider_id'] as String?,
        serviceType: record['service_type'] as String? ?? '',
        serviceIcon: record['service_icon'] as String? ?? 'build',
        driverName: 'Customer',
        driverPhone: '',
        address: record['address'] as String? ?? '',
        distanceMiles: distance,
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
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.warning),
            const SizedBox(width: 8),
            Text(l.t('limit_reached')),
          ],
        ),
        content: Text(
          l.t('plan_limit_message')
              .replaceAll('{limit}', '$limit')
              .replaceAll('{type}', type),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentTabIndex = 2); // Switch to Plans tab
            },
            child: Text(l.t('upgrade_plan')),
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
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) {
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
      if (_enabledServices.isEmpty) {
      }
      
      for (final id in _enabledServices) {
        final pricing = _pricingMap[id];
        if (pricing == null) {
          continue;
        }
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
      if (servicesToSave.isEmpty) {
      }
      
      await SupabaseService.instance.saveProviderServices(
        userId,
        servicesToSave,
      );
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

    // Block quote if subscription is paused or inactive
    if (!_hasActiveSubscription || _isSubscriptionPaused) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('subscription_required'),
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            l.t('subscription_paused_desc'),
            style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showPlanPurchaseDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(l.t('subscribe_now')),
            ),
          ],
        ),
      );
      return;
    }

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

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final ts = ThemeService.instance;
    final bgImage = ts.providerMainScreenBgImageUrl;
    final bgOpacity = ts.providerMainScreenBgOpacity;
    final bgColor = ts.providerMainScreenBg.withAlpha((255 * bgOpacity).round());
    return Scaffold(
      backgroundColor: bgImage.isEmpty ? bgColor : null,
      appBar: null,
      body: Container(
        decoration: bgImage.isNotEmpty
          ? BoxDecoration(
              image: DecorationImage(image: NetworkImage(bgImage), fit: BoxFit.cover),
              color: bgColor,
            )
          : null,
        child: SafeArea(
          child: Column(
            children: [
              // Subscription required banner
              if (!_hasActiveSubscription)
                _buildSubscriptionRequiredBanner(l),
              ProviderStatsHeaderWidget(
                jobs: _jobs,
                selectedStatus: _selectedStatusFilter,
                onStatusChanged: _onStatusFilterChanged,
                providerName: _providerName,
                locationLabel: _locationLabel,
                isAvailable: _isAvailable,
                onAvailabilityToggle: _toggleAvailability,
                isLoadingAvailability: _isSavingAvailability,
                averageRating: _averageRating,
                isLoadingRating: _isLoadingStats,
                onNotificationPressed: () {},
                onProfilePressed: () => Navigator.pushNamed(context, AppRoutes.providerProfileScreen),
              ),
              _buildTabSelector(l),
              Expanded(child: _buildTabContent(l)),
            ],
          ),
        ),
      ),
      floatingActionButton: null,  // Send quote button removed per requirements
    );
  }

  Widget _buildTabSelector(LocalizationService l) {
    final ts = ThemeService.instance;
    final tabs = [
      {'label': l.t('job_requests'), 'icon': Icons.work_outline_rounded},
      {
        'label': l.t('my_services_pricing'),
        'icon': Icons.build_circle_outlined,
      },
    ];

    return Container(
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
                      ? ts.providerMainTabSelectedBg
                      : ts.providerMainTabUnselectedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: ts.providerMainCardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      size: 18,
                      color: isSelected
                          ? ts.providerMainTabSelectedText
                          : ts.providerMainTabUnselectedText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tabs[index]['label'] as String,
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? ts.providerMainTabSelectedText
                            : ts.providerMainTabUnselectedText,
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
        label: Text(
          l.t('status_done').toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
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
        ? l.t('unlimited_categories')
        : l.t('categories_used')
            .replaceAll('{current}', '${_enabledServices.length}')
            .replaceAll('{max}', '$maxCats');

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
                    l.t('select_services_pricing_rules'),
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
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
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
        mainAxisSize: MainAxisSize.min,
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
              maxRange: _maxServiceRange,
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
                      l.t('set_location_in_profile'),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.t('go_to_profile_coordinates'),
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

  // ─── LEGACY PLAN METHODS REMOVED ────────────────────────────────────────────
  // Plan subscription is now handled via ProviderPlanPurchaseDialog
  // Accessed through the "Subscribe" button in subscription required banner
  // or through Provider Profile > Subscribe Now

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

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 3959; // miles
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
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
    final String? iconImageUrl = service['icon_image_url'] as String?;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: iconImageUrl != null && iconImageUrl.isNotEmpty
            ? EdgeInsets.zero
            : const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled ? AppTheme.primary : AppTheme.outlineVariant,
            width: 2,
          ),
        ),
        clipBehavior: iconImageUrl != null && iconImageUrl.isNotEmpty
            ? Clip.antiAlias
            : Clip.none,
        child: iconImageUrl != null && iconImageUrl.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Full background image
                  Image.network(
                    iconImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: isEnabled
                          ? AppTheme.primary.withAlpha(30)
                          : AppTheme.surfaceVariant,
                      child: Center(
                        child: Text(iconEmoji, style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                  ),
                  // Dark gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(0),
                          Colors.black.withAlpha(100),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Content overlay
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isEnabled)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(200),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: AppTheme.primary,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          name,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha(150),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppTheme.primary.withAlpha(30)
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                        ),
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
    final String? iconImageUrl = service['icon_image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          iconImageUrl != null && iconImageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: Image.network(
                    iconImageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: AppTheme.surfaceVariant,
                      child: Center(
                        child: Text(iconEmoji, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                )
              : Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Text(iconEmoji, style: const TextStyle(fontSize: 32)),
                  ),
                ),
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
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('base_service_price'),
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
          l.t('supported_vehicles'),
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.t('supported_vehicles_desc'),
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
                setState(() {
                  if (isSelected) {
                    _supportedVehicles.remove(opt['id']);
                  } else {
                    _supportedVehicles.add(opt['id'] as String);
                  }
                });
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
                      AppConstants.getVehicleSizeLabel(opt['id'] as String),
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
              LocalizationService.instance.t('after_hours_rates'),
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
          label: Text(LocalizationService.instance.t('add_time_rule')),
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
