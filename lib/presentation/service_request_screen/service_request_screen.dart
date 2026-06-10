import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

import '../../routes/app_routes.dart';
import 'package:roadrescue_shared/config/app_constants.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/location_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import './widgets/request_form_widget.dart';
import './widgets/request_submit_button_widget.dart';
import './widgets/service_category_grid_widget.dart';
import './widgets/active_request_banner_widget.dart';
import './widgets/hero_section_widget.dart';
import './widgets/service_request_popup_shape.dart';
import './widgets/popup_location_map_widget.dart';
import 'package:roadrescue_shared/widgets/themed_alert_dialog.dart';

class ServiceRequestScreen extends StatefulWidget {
  final VoidCallback? onNavigateToActiveRequests;

  const ServiceRequestScreen({super.key, this.onNavigateToActiveRequests});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  String? _selectedCategory;
  String? _selectedVehicleSize;
  String? _selectedVehicleId;
  String _urgencyLevel = 'standard';
  bool _isSubmitting = false;

  // Service-specific state
  String? _selectedFuelType;
  double? _selectedFuelAmount;
  String? _selectedTirePosition;
  String? _selectedTireAction;

  // GPS location state
  double? _locationLat;
  double? _locationLng;
  String? _locationAddress;

  // Active help request state (backed by real DB)
  ActiveHelpRequest? _activeRequest;
  RealtimeChannel? _requestSubscription;

  List<Map<String, dynamic>> _dynamicCategories = [];
  bool _isLoadingCats = true;
  String? _userName;
  String? _cityName;
  String? _avatarUrl;

  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> get _vehicleSizeOptions => AppConstants.vehicleSizeOptions;

  List<Map<String, dynamic>> get _availableVehicleSizes {
    if (_selectedCategory == null) return [];
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id']?.toString() == _selectedCategory,
        orElse: () => {},
      );
      if (cat.isEmpty) return [];

      final sizesRaw = cat['vehicle_sizes'];
      List<dynamic> sizes = [];
      if (sizesRaw is List) {
        sizes = sizesRaw;
      } else if (sizesRaw is String) {
        try {
          sizes = json.decode(sizesRaw) as List;
        } catch (_) {}
      }

      return _vehicleSizeOptions.where((v) => sizes.contains(v['id'])).toList();
    } catch (_) {
      return [];
    }
  }

  String get _selectedCategoryLabel {
    if (_selectedCategory == null) return '';
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id']?.toString() == _selectedCategory,
        orElse: () => {},
      );
      if (cat.isEmpty) return '';
      return _getCategoryName(cat);
    } catch (_) {
      return '';
    }
  }

  String get _selectedCategoryCode {
    if (_selectedCategory == null) return '';
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id']?.toString() == _selectedCategory,
        orElse: () => {},
      );
      if (cat.isEmpty) return '';
      return cat['code'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get _isGasService => _selectedCategoryCode == 'fuel_delivery';
  bool get _isFlatTireService => _selectedCategoryCode == 'flat_tire';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadCategories(), _loadUserName()]);
      await _loadActiveRequest();
      // Run GPS after user data so GPS-derived city/state overrides profile fallback
      await _autoAcquireGps();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCats = false;
        });
      }
    }
  }

  /// Extract "City, State" from a Nominatim display_name string.
  String _extractCityState(String displayName) {
    final parts = displayName.split(',').map((s) => s.trim()).toList();
    if (parts.length < 2) return displayName;

    // Remove likely postcode (short numeric) and country names
    final clean = parts.where((p) {
      if (RegExp(r'^\d{3,8}$').hasMatch(p.trim())) return false;
      final lower = p.toLowerCase();
      if ([
        'united states',
        'usa',
        'united kingdom',
        'canada',
        'mexico',
        'germany',
        'france',
        'spain',
        'italy',
      ].contains(lower)) return false;
      return true;
    }).toList();

    if (clean.length >= 2) {
      // Typical Nominatim order: …, City, County/Region, State, …
      // Try city (length-3) + state (length-1)
      final city = clean.length >= 3 ? clean[clean.length - 3] : clean[clean.length - 2];
      final state = clean.last;
      return '$city, $state';
    }
    return displayName;
  }

  Future<void> _autoAcquireGps() async {
    try {
      // Check if we already have a cached location
      final cached = await LocationService.getLastKnownLocation();
      if (cached != null) {
        final address = cached['address'] as String? ?? '';
        if (mounted) {
          setState(() {
            _locationLat = cached['lat'] as double?;
            _locationLng = cached['lng'] as double?;
            _locationAddress = address;
            _cityName = _extractCityState(address);
          });
        }
        return;
      }

      // Request permission and acquire GPS
      final permission = await LocationService.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await LocationService.getCurrentPosition(
        timeout: const Duration(seconds: 8),
      );
      if (position == null) {
        return;
      }

      final address = await LocationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final resolvedAddress = address ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      await LocationService.saveLastKnownLocation(
        position.latitude,
        position.longitude,
        resolvedAddress,
      );

      if (mounted) {
        setState(() {
          _locationLat = position.latitude;
          _locationLng = position.longitude;
          _locationAddress = resolvedAddress;
          _cityName = _extractCityState(resolvedAddress);
        });
      }
    } catch (e) {
    }
  }

  Future<void> _refreshLocation() async {
    await LocationService.clearCachedLocation();
    await _autoAcquireGps();
  }

  Future<void> _loadUserName() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseService.instance.getUserProfile(userId);
      if (profile != null && mounted) {
        String? cityName;
        final cityId = profile['selected_city_id'] as String?;
        if (cityId != null) {
          try {
            final cityRes = await Supabase.instance.client
                .from('cities')
                .select('name')
                .eq('id', cityId)
                .maybeSingle();
            cityName = cityRes?['name'] as String?;
          } catch (_) {}
        }
        setState(() {
          _userName = profile['full_name'] as String?;
          _cityName = cityName ?? profile['address'] as String?;
          _avatarUrl = profile['avatar_url'] as String?;
        });
      }
    } catch (e) {
    }
  }

  String _getGreeting(LocalizationService l) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l.t('good_morning');
    if (hour < 18) return l.t('good_afternoon');
    return l.t('good_evening');
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCats = true);
    final cats = await SupabaseService.instance.getServiceCategories();
    if (mounted) {
      setState(() {
        _dynamicCategories = cats;
        _isLoadingCats = false;
      });
      // Pre-cache category icon images for faster display
      for (final cat in cats) {
        final iconUrl = cat['icon_image_url'] as String?;
        if (iconUrl != null && iconUrl.isNotEmpty) {
          precacheImage(NetworkImage(iconUrl), context);
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _requestSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActiveRequest() async {
    try {
      final data = await SupabaseService.instance.getActiveJobRequest();
      if (mounted) {
        if (data != null) {
          final request = _mapToActiveRequest(data);
          setState(() => _activeRequest = request);
          _subscribeToRequest(data['id']?.toString() ?? '');
        } else {
          // Explicitly clear if no active request found
          setState(() => _activeRequest = null);
        }
      }
    } catch (e) {
    }
  }

  void _subscribeToRequest(String requestId) {
    _requestSubscription?.unsubscribe();
    _requestSubscription = SupabaseService.instance.subscribeToJobRequest(
      requestId,
      (record) async {
        if (!mounted) return;

        final status = record['job_status'] as String? ?? '';

        // If completed or cancelled, clear active request immediately.
        // The review dialog is shown directly by the widget that handled
        // the user's completion tap (ActiveRequestBannerWidget).
        if (status == 'completed' || status == 'cancelled') {
          setState(() => _activeRequest = null);
          _requestSubscription?.unsubscribe();
          _requestSubscription = null;
          return;
        }

        // Optimistically update key fields from the realtime payload
        // so the UI reflects changes immediately without waiting for re-fetch.
        if (_activeRequest != null && _activeRequest!.id == requestId) {
          final optimisticStatusStr = record['job_status'] as String?;
          final optimisticPrice = record['quoted_price'] != null
              ? (record['quoted_price'] as num).toDouble()
              : _activeRequest!.quotedPrice;
          final optimisticEta = record['eta_minutes'] as int? ?? _activeRequest!.etaMinutes;
          if (optimisticStatusStr != null) {
            HelpRequestStatus optimisticStatus;
            switch (optimisticStatusStr) {
              case 'quoted':
                optimisticStatus = HelpRequestStatus.quoted;
                break;
              case 'accepted':
              case 'confirmed':
                optimisticStatus = HelpRequestStatus.accepted;
                break;
              case 'en_route':
              case 'in_progress':
                optimisticStatus = HelpRequestStatus.enRoute;
                break;
              case 'awaiting_confirmation':
                optimisticStatus = HelpRequestStatus.awaitingConfirmation;
                break;
              case 'awaiting_reconfirmation':
                optimisticStatus = HelpRequestStatus.awaitingReconfirmation;
                break;
              case 'disputed':
                optimisticStatus = HelpRequestStatus.disputed;
                break;
              default:
                optimisticStatus = HelpRequestStatus.pending;
            }
            setState(() {
              _activeRequest = _activeRequest!.copyWith(
                status: optimisticStatus,
                quotedPrice: optimisticPrice,
                etaMinutes: optimisticEta,
              );
            });
          }
        }

        // Re-fetch full record with joins after a short delay
        // so read replicas have time to catch up.
        await Future.delayed(const Duration(milliseconds: 300));
        // Still active — re-fetch full record with joins
        final updated = await SupabaseService.instance.getActiveJobRequest();
        if (mounted && updated != null) {
          setState(() => _activeRequest = _mapToActiveRequest(updated));
        }
      },
    );
  }

  ActiveHelpRequest _mapToActiveRequest(Map<String, dynamic> data) {
    final provider = data['provider'] as Map<String, dynamic>?;
    final statusStr = data['job_status'] as String? ?? 'pending';
    HelpRequestStatus status;
    switch (statusStr) {
      case 'quoted':
        status = HelpRequestStatus.quoted;
        break;
      case 'accepted':
      case 'confirmed':
        status = HelpRequestStatus.accepted;
        break;
      case 'en_route':
      case 'in_progress':
        status = HelpRequestStatus.enRoute;
        break;
      case 'awaiting_confirmation':
        status = HelpRequestStatus.awaitingConfirmation;
        break;
      case 'awaiting_reconfirmation':
        status = HelpRequestStatus.awaitingReconfirmation;
        break;
      case 'disputed':
        status = HelpRequestStatus.disputed;
        break;
      case 'completed':
        status = HelpRequestStatus.completed;
        break;
      case 'cancelled':
        status = HelpRequestStatus.cancelled;
        break;
      default:
        status = HelpRequestStatus.pending;
    }

    return ActiveHelpRequest(
      id: data['id']?.toString() ?? '',
      serviceType: _resolveServiceTypeName(data['service_type'] as String? ?? ''),
      serviceIcon: data['service_icon'] as String? ?? 'build',
      serviceIconImageUrl: data['service_icon_image_url'] as String?,
      address: data['address'] as String? ?? '',
      description: data['description'] as String? ?? '',
      urgency: data['urgency'] as String? ?? 'standard',
      status: status,
      submittedAt:
          DateTime.tryParse(data['created_at'] as String? ?? '') ??
          DateTime.now(),
      customerConfirmation: data['customer_confirmation'] as bool?,
      providerConfirmation: data['provider_confirmation'] as bool?,
      confirmationRound: (data['confirmation_round'] as num?)?.toInt() ?? 0,
      providerName: provider?['full_name'] as String?,
      providerPhone: provider?['phone'] as String?,
      providerBusiness: provider?['business_name'] as String?,
      providerImageUrl: provider?['avatar_url'] as String?,
      quotedPrice: (data['quoted_price'] as num?)?.toDouble(),
      etaMinutes: data['eta_minutes'] as int?,
      fuelType: data['fuel_type'] as String?,
      fuelAmount: (data['fuel_amount'] as num?)?.toDouble(),
      tirePosition: data['tire_position'] as String?,
      tireAction: data['tire_action'] as String?,
      customerLat: (data['customer_lat'] as num?)?.toDouble(),
      customerLng: (data['customer_lng'] as num?)?.toDouble(),
      vehicleId: data['vehicle_id'] as String?,
      vehicleMake: data['vehicle_make'] as String?,
      vehicleModel: data['vehicle_model'] as String?,
      vehicleColor: data['vehicle_color'] as String?,
      vehicleYear: data['vehicle_year'] as String?,
      vehiclePlate: data['vehicle_plate'] as String?,
      vehicleType: data['vehicle_type'] as String?,
      vehicleSize: data['vehicle_size'] as String?,
    );
  }

  void _onCategorySelected(String id) {
    setState(() {
      _selectedCategory = id;
      _selectedVehicleSize = null;
      _selectedFuelType = null;
      _selectedFuelAmount = null;
      _selectedTirePosition = null;
      _selectedTireAction = null;
    });
    _showRequestDetailsSheet();
  }

  void _onUrgencyChanged(String level) {
    setState(() => _urgencyLevel = level);
  }

  Future<void> _onSubmit({BuildContext? popupContext}) async {
    final l = LocalizationService.instance;
    if (_selectedCategory == null) {
      if (popupContext != null && popupContext.mounted) {
        Navigator.pop(popupContext);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t('select_service'),
            style: GoogleFonts.manrope(fontSize: 14),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Determine vehicle size and full vehicle details
    String vehicleSizeToSubmit = _selectedVehicleSize ?? '';
    Map<String, dynamic>? vehicleToSubmit;
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId != null) {
      try {
        final vehicles = await SupabaseService.instance.getUserVehicles(userId);
        if (vehicles.isNotEmpty) {
          final primary = vehicles.firstWhere((v) => v['is_primary'] == true, orElse: () => vehicles.first);
          vehicleToSubmit = vehicles.firstWhere((v) => v['id'] == _selectedVehicleId, orElse: () => primary);
          vehicleSizeToSubmit = vehicleToSubmit['vehicle_type'] as String? ?? '';
        } else if (!_isGasService && _availableVehicleSizes.isNotEmpty && _selectedVehicleSize == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.t('vehicle_size_subtitle'), style: GoogleFonts.manrope(fontSize: 14)),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
      } catch (_) {
        if (!_isGasService && _availableVehicleSizes.isNotEmpty && _selectedVehicleSize == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.t('vehicle_size_subtitle'), style: GoogleFonts.manrope(fontSize: 14)),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id'].toString() == _selectedCategory,
        orElse: () => {'icon_emoji': 'build'},
      );
      final serviceIcon = cat['icon_emoji'] ?? 'build';
      final serviceIconImageUrl = cat['icon_image_url'] as String?;

      final data = await SupabaseService.instance.createJobRequest(
        serviceType: _selectedCategoryLabel,
        serviceIcon: serviceIcon,
        serviceIconImageUrl: serviceIconImageUrl,
        vehicleSize: vehicleSizeToSubmit,
        address: _locationAddress ?? '',
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : l.t('no_additional_details'),
        urgency: _urgencyLevel,
        customerLat: _locationLat,
        customerLng: _locationLng,
        fuelType: _isGasService ? _selectedFuelType : null,
        fuelAmount: _isGasService ? _selectedFuelAmount : null,
        tirePosition: _isFlatTireService ? _selectedTirePosition : null,
        tireAction: _isFlatTireService ? _selectedTireAction : null,
        vehicleId: vehicleToSubmit?['id'] as String?,
        vehicleMake: vehicleToSubmit?['make'] as String?,
        vehicleModel: vehicleToSubmit?['model'] as String?,
        vehicleColor: vehicleToSubmit?['color'] as String?,
        vehicleYear: vehicleToSubmit?['year'] as String?,
        vehiclePlate: vehicleToSubmit?['plate_number'] as String?,
        vehicleType: vehicleToSubmit?['vehicle_type'] as String?,
      );

      if (popupContext != null && popupContext.mounted) {
        Navigator.pop(popupContext);
      }

      final newRequest = _mapToActiveRequest(data);
      setState(() {
        _activeRequest = newRequest;
        _selectedCategory = null;
        _selectedVehicleSize = null;
        _selectedVehicleId = null;
        _selectedFuelType = null;
        _selectedFuelAmount = null;
        _selectedTirePosition = null;
        _selectedTireAction = null;
        _descriptionController.clear();
      });

      _subscribeToRequest(data['id']?.toString() ?? '');
      _showRequestSubmittedDialog(data['id']?.toString() ?? '');
    } catch (e) {
      debugPrint('Job request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l.t('generic_error')}: ${e.toString()}',
              style: GoogleFonts.manrope(fontSize: 14),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showRequestDetailsSheet() {
    final l = LocalizationService.instance;
    final userId = SupabaseService.instance.currentUser?.id;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Service Request',
      barrierColor: Colors.black.withAlpha(160),
      pageBuilder: (ctx, anim1, anim2) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final ts = ThemeService.instance;
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: userId != null ? SupabaseService.instance.getUserVehicles(userId) : Future.value([]),
            builder: (context, vehiclesSnapshot) {
              final hasVehicles = (vehiclesSnapshot.data ?? []).isNotEmpty;
              return Material(
                type: MaterialType.transparency,
                child: Center(
                  child: Container(
                    width: MediaQuery.of(ctx).size.width * 0.9,
                    height: MediaQuery.of(ctx).size.height * 0.8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.rectangle,
                    ),
                    child: CustomPaint(
                      painter: _GlowBorderPainter(),
                      child: ClipPath(
                          clipper: ServiceRequestPopupClipper(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.serviceRequestBackground.withAlpha((255 * ts.serviceRequestPopupBgOpacity).round()),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Back button + service icon on same row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          setState(() {
                                            _selectedCategory = null;
                                            _selectedVehicleSize = null;
                                            _selectedVehicleId = null;
                                          });
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(20),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppTheme.serviceRequestBorder),
                                          ),
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: AppTheme.serviceRequestBorder,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      _buildServiceIcon(),
                                      const Spacer(),
                                      const SizedBox(width: 40),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Service name
                                  Text(
                                    _selectedCategoryLabel,
                                    style: GoogleFonts.manrope(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),

                                  // Vehicle type selection (except fuel service) -- only if user has NO vehicles
                                  if (!hasVehicles && !_isGasService && _availableVehicleSizes.isNotEmpty) ...[
                                    _buildVehicleTypeSelector(sheetSetState),
                                    const SizedBox(height: 20),
                                  ],

                                  // Vehicle info display
                                  _buildVehicleInfoDisplay(),
                                  const SizedBox(height: 20),
                              
                              // Map + street name (self-contained)
                              PopupLocationMapWidget(
                                height: 120,
                                onLocationDetected: (lat, lng, address) {
                                  setState(() {
                                    _locationLat = lat;
                                    _locationLng = lng;
                                    _locationAddress = address;
                                    _cityName = _extractCityState(address);
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Fuel type selector (Gas service only)
                              if (_isGasService) ...[
                                _buildFuelTypeSelector(sheetSetState),
                                const SizedBox(height: 20),
                              ],
                              
                              // Gas amount selector (Gas service only)
                              if (_isGasService) ...[
                                _buildGasAmountSelector(sheetSetState),
                                const SizedBox(height: 20),
                              ],
                              
                              // Tire position selector (Flat Tire only)
                              if (_isFlatTireService) ...[
                                _buildVehicleTireSelector(sheetSetState),
                                const SizedBox(height: 20),
                              ],
                              
                              // Tire action buttons (Flat Tire only)
                              if (_isFlatTireService && _selectedTirePosition != null) ...[
                                _buildTireActionButtons(sheetSetState),
                                const SizedBox(height: 20),
                              ],
                              
                              // Details & urgency
                              RequestFormWidget(
                                controller: _descriptionController,
                                urgencyLevel: _urgencyLevel,
                                onUrgencyChanged: (level) {
                                  _onUrgencyChanged(level);
                                  sheetSetState(() {});
                                },
                              ),
                              const SizedBox(height: 24),
                              
                              // Submit buttons
                              _buildSubmitButtons(ctx, hasVehicles: hasVehicles),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
  }

  Widget _buildServiceIcon() {
    final category = _dynamicCategories.firstWhere(
      (cat) => cat['id']?.toString() == _selectedCategory,
      orElse: () => {},
    );
    final iconImageUrl = category['icon_image_url'] as String?;
    
    if (iconImageUrl != null && iconImageUrl.isNotEmpty) {
      return Image.network(
        iconImageUrl,
        width: 160,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.local_car_wash,
            size: 80,
            color: AppTheme.serviceRequestAccent,
          );
        },
      );
    } else {
      // Fallback to emoji
      return Text(
        _getCategoryEmoji(_selectedCategory),
        style: const TextStyle(fontSize: 80),
      );
    }
  }

  String _getCategoryEmoji(String? categoryId) {
    final category = _dynamicCategories.firstWhere(
      (cat) => cat['id']?.toString() == categoryId,
      orElse: () => {'emoji': '🚗'},
    );
    return category['emoji'] as String? ?? '🚗';
  }

  Widget _buildVehicleInfoDisplay() {
    final l = LocalizationService.instance;
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.instance.getUserVehicles(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: AppTheme.serviceRequestAccent, size: 20),
                const SizedBox(width: 8),
                Text(l.t('loading'), style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(180))),
              ],
            ),
          );
        }

        final vehicles = snapshot.data ?? [];
        if (vehicles.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: AppTheme.serviceRequestAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.t('vehicle_info_prefix') + ' ' + l.t('no_vehicle_set'),
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          );
        }

        final primary = vehicles.firstWhere((v) => v['is_primary'] == true, orElse: () => vehicles.first);
        final selectedVehicleId = _selectedVehicleId ?? primary['id'] as String;
        final selectedVehicle = vehicles.firstWhere((v) => v['id'] == selectedVehicleId, orElse: () => primary);
        final display = SupabaseService.instance.formatVehicleDisplay(selectedVehicle);
        final hasMultiple = vehicles.length > 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                l.t('vehicle_info_prefix'),
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(180)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: hasMultiple ? () => _showVehiclePicker(context, vehicles, selectedVehicleId) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.serviceRequestAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.serviceRequestAccent.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_rounded, size: 16, color: AppTheme.serviceRequestAccent),
                      const SizedBox(width: 6),
                      Text(
                        display,
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (hasMultiple) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.serviceRequestAccent),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVehiclePicker(BuildContext context, List<Map<String, dynamic>> vehicles, String currentId) {
    final otherVehicles = vehicles.where((v) => v['id'] != currentId).toList();
    if (otherVehicles.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    LocalizationService.instance.t('vehicle_info_prefix'),
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...otherVehicles.map((v) {
                final display = SupabaseService.instance.formatVehicleDisplay(v);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedVehicleId = v['id'] as String);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          display,
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTypeSelector(StateSetter sheetSetState) {
    return _buildVehicleSizePicker(
      LocalizationService.instance,
      onChanged: () => sheetSetState(() {}),
    );
  }

  Widget _buildSubmitButtons(BuildContext ctx, {required bool hasVehicles}) {
    final l = LocalizationService.instance;
    final needsVehicleSize = !hasVehicles && !_isGasService && _availableVehicleSizes.isNotEmpty;
    return Column(
      children: [
        // Yellow submit button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_selectedCategory != null &&
                (!needsVehicleSize || _selectedVehicleSize != null) &&
                (!_isGasService || _selectedFuelType != null) &&
                (!_isGasService || _selectedFuelAmount != null) &&
                (!_isFlatTireService || _selectedTirePosition != null) &&
                (!_isFlatTireService || _selectedTireAction != null))
                ? () => _onSubmit(popupContext: ctx)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.serviceRequestAccent,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '${l.t('confirm')} & ${l.t('submit_request')} — $_selectedCategoryLabel'.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Dark blue back button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedCategory = null;
                _selectedVehicleSize = null;
                _selectedVehicleId = null;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppTheme.serviceRequestAccent,
              side: BorderSide(color: AppTheme.serviceRequestAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.t('cancel').toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestSubmittedDialog(String requestId) {
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ThemedAlertDialog(role: 'customer',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.successContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 36,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.t('request_submitted'),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.t('searching_providers_info'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.t('chat_available_after_quote'),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l.t('track_my_request'),
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
    );
  }

  void _openRequestDetail() {
    if (_activeRequest == null) return;

    // Navigate to Active Requests tab instead of showing popup
    widget.onNavigateToActiveRequests?.call();
  }

  Future<void> _cancelRequest() async {
    if (_activeRequest == null) return;
    final l = LocalizationService.instance;
    try {
      await SupabaseService.instance.cancelJobRequest(_activeRequest!.id);
      _requestSubscription?.unsubscribe();
      _requestSubscription = null;
      if (mounted) {
        setState(() => _activeRequest = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('help_request_cancelled'),
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
    } catch (_) {
      if (mounted) {
        setState(() => _activeRequest = null);
      }
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    await ThemeService.instance.initialize();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signUpLoginScreen,
        (r) => false,
      );
    }
  }

  /// Resolve the current-locale category name from a stored service_type string.
  /// Matches the stored value against all translation values in _dynamicCategories.
  String _resolveServiceTypeName(String storedName) {
    if (storedName.isEmpty || _dynamicCategories.isEmpty) return storedName;
    for (final cat in _dynamicCategories) {
      // Check if storedName matches any translation value or the base name
      final baseName = cat['name'] as String? ?? '';
      if (baseName == storedName) return _getCategoryName(cat);
      final translationsRaw = cat['name_translations'];
      Map<String, dynamic> translations = {};
      if (translationsRaw is Map) {
        translations = translationsRaw.map((k, v) => MapEntry(k.toString(), v));
      } else if (translationsRaw is String) {
        try {
          translations = (json.decode(translationsRaw) as Map)
              .map((k, v) => MapEntry(k.toString(), v));
        } catch (_) {}
      }
      if (translations.values.any((v) => v?.toString() == storedName)) {
        return _getCategoryName(cat);
      }
    }
    return storedName;
  }

  String _getCategoryName(Map<String, dynamic> category) {
    final l = LocalizationService.instance;
    final translationsRaw = category['name_translations'];
    Map<String, dynamic> translations = {};

    if (translationsRaw is Map) {
      translations = translationsRaw.map((k, v) => MapEntry(k.toString(), v));
    } else if (translationsRaw is String) {
      try {
        translations = (json.decode(translationsRaw) as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        );
      } catch (_) {}
    }

    return l.translateContent(
      translations,
      fallbackText: category['name'] as String? ?? '',
    );
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  /// Get vehicle size images map from selected category, handling Supabase JSON types
  Map<String, dynamic> _getVehicleImagesForCategory() {
    if (_selectedCategory == null) return {};
    
    // Look up category from _dynamicCategories using the ID
    final category = _dynamicCategories.firstWhere(
      (c) => c['id']?.toString() == _selectedCategory,
      orElse: () => {},
    );
    if (category.isEmpty) return {};
    
    final rawImages = category['vehicle_size_images'];
    if (rawImages == null) return {};
    
    // Supabase may return JSON as Map or as encoded JSON string
    if (rawImages is Map<String, dynamic>) {
      return rawImages;
    } else if (rawImages is Map) {
      return Map<String, dynamic>.from(rawImages);
    } else if (rawImages is String) {
      // Try to decode JSON string
      try {
        final decoded = jsonDecode(rawImages);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListenableBuilder(
        listenable: ThemeService.instance,
        builder: (context, _) {
          final ts = ThemeService.instance;
          final screenBg = ts.userScreenBgColor.withAlpha((255 * ts.userScreenBgOpacity).round());
          final screenBgImage = ts.userScreenBgImageUrl;

          Widget body = SafeArea(
            child: Column(
              children: [
                HeroSectionWidget(
                  cityName: _cityName,
                  greeting: _getGreeting(l),
                  userName: _userName,
                  locationAddress: _locationAddress,
                  etaMinutes: _activeRequest?.etaMinutes,
                  onRefreshLocation: _refreshLocation,
                  onNotificationTap: () {},
                ),
                Expanded(
                  child: _isTablet ? _buildTabletLayout(l) : _buildPhoneLayout(l),
                ),
              ],
            ),
          );

          if (screenBgImage.isNotEmpty) {
            body = Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  screenBgImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: screenBg),
                ),
                Container(color: screenBg),
                body,
              ],
            );
          } else {
            body = Container(
              color: screenBg,
              child: body,
            );
          }

          return body;
        },
      ),
    );
  }

  Widget _buildPhoneLayout(LocalizationService l) {
    if (_isLoadingCats) {
      return const Center(child: CircularProgressIndicator());
    }

    final ts = ThemeService.instance;
    final List<Map<String, dynamic>> mappedCategories = [];
    for (final c in _dynamicCategories) {
      try {
        mappedCategories.add({
          'id': c['id']?.toString() ?? '',
          'label': _getCategoryName(c),
          'icon': c['icon_emoji'] ?? 'build',
          'iconImageUrl': c['icon_image_url'] as String?,
        });
      } catch (e) {
      }
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              l.t('what_do_you_need'),
              l.t('select_service_subtitle'),
            ),
            const SizedBox(height: 12),
            if (mappedCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    l.t('no_services_available'),
                    style: GoogleFonts.manrope(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ServiceCategoryGridWidget(
                categories: mappedCategories,
                selectedId: _selectedCategory,
                onSelected: _onCategorySelected,
                crossAxisCount: 3,
              ),
            const SizedBox(height: 24),
            // Current Services section
            if (_activeRequest != null &&
                _activeRequest!.status != HelpRequestStatus.cancelled) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.t('current_services'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ts.activeServicesTextColor,
                  ),
                ),
              ),
              ActiveRequestBannerWidget(
                request: _activeRequest!,
                onTap: _openRequestDetail,
                onRefresh: _loadActiveRequest,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSizePicker(LocalizationService l, {VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPopupSectionHeader(l.t('vehicle_size'), l.t('vehicle_size_subtitle')),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableVehicleSizes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final vehicle = _availableVehicleSizes[index];
              final isSelected = _selectedVehicleSize == vehicle['id'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedVehicleSize = vehicle['id'] as String);
                  onChanged?.call();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 85,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : AppTheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withAlpha(64),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Check for custom image first, then fall back to emoji
                      Builder(
                        builder: (context) {
                          final vehicleImages = _getVehicleImagesForCategory();
                          final imageUrl = vehicleImages[vehicle['id']] as String?;
                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(vehicle['emoji'] as String, style: const TextStyle(fontSize: 26)),
                              ),
                            );
                          }
                          return Text(
                            vehicle['emoji'] as String,
                            style: const TextStyle(fontSize: 26),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.getVehicleSizeLabel(vehicle['id'] as String),
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.black
                              : Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<dynamic> get _gasAmountOptions {
    if (_selectedCategory == null) return [];
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id']?.toString() == _selectedCategory,
        orElse: () => {},
      );
      if (cat.isEmpty) return [];
      final raw = cat['gas_amount_options'];
      if (raw is List) return raw;
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    } catch (_) {}
    return [];
  }

  Widget _buildFuelTypeSelector(StateSetter sheetSetState) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPopupSectionHeader(l.t('fuel_type'), l.t('select_fuel_type')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.fuelTypeOptions.map((fuel) {
            final isSelected = _selectedFuelType == fuel['id'] as String;
            return ChoiceChip(
              label: Text(
                l.t('fuel_type_${fuel['id']}'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.serviceRequestAccent,
              backgroundColor: isSelected ? AppTheme.serviceRequestAccent : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(120),
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFuelType = fuel['id'] as String);
                  sheetSetState(() {});
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGasAmountSelector(StateSetter sheetSetState) {
    final l = LocalizationService.instance;
    final amounts = _gasAmountOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPopupSectionHeader(l.t('gas_amount'), l.t('select_gas_amount')),
        const SizedBox(height: 12),
        if (amounts.isEmpty)
          Text(
            l.t('no_gas_amounts_configured'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white70,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: amounts.map((amount) {
              final value = (amount is num) ? amount.toDouble() : 0.0;
              final isSelected = _selectedFuelAmount == value;
              return ChoiceChip(
                label: Text(
                  '\$${value % 1 == 0 ? value.toInt() : value}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.serviceRequestAccent,
                backgroundColor: isSelected ? AppTheme.serviceRequestAccent : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(120),
                    width: 1.5,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFuelAmount = value);
                    sheetSetState(() {});
                  }
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildVehicleTireSelector(StateSetter sheetSetState) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Damaged Tire',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.serviceRequestAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the tire position that needs service',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.serviceRequestBorder, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vehicle body outline
                Container(
                  width: 120,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.serviceRequestBorder, width: 2),
                  ),
                ),
                // Front label
                Positioned(
                  top: 4,
                  child: Text(
                    'FRONT',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.serviceRequestAccent,
                    ),
                  ),
                ),
                // Rear label
                Positioned(
                  bottom: 4,
                  child: Text(
                    'REAR',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.serviceRequestAccent,
                    ),
                  ),
                ),
                // Tires with yellow theme
                ...AppConstants.tirePositionOptions.map((tire) {
                  final id = tire['id'] as String;
                  final isSelected = _selectedTirePosition == id;
                  // Position offsets for 180x120 container
                  double left = 0, top = 0;
                  switch (id) {
                    case 'front_left':
                      left = 20; top = 20;
                      break;
                    case 'front_right':
                      left = 132; top = 20;
                      break;
                    case 'rear_left':
                      left = 20; top = 72;
                      break;
                    case 'rear_right':
                      left = 132; top = 72;
                      break;
                  }
                  return Positioned(
                    left: left,
                    top: top,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTirePosition = id);
                        sheetSetState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.serviceRequestAccent
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : AppTheme.serviceRequestBorder,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.serviceRequestAccent.withAlpha(100),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.tire_repair,
                            size: 16,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedTirePosition != null)
          Center(
            child: Text(
              'Selected: ${AppConstants.tirePositionOptions.firstWhere((t) => t['id'] == _selectedTirePosition)['label']}',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.serviceRequestAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTireActionButtons(StateSetter sheetSetState) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPopupSectionHeader(l.t('tire_action'), l.t('choose_tire_action')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.tireActionOptions.map((action) {
            final isSelected = _selectedTireAction == action['id'] as String;
            return ChoiceChip(
              label: Text(
                l.t('tire_action_${action['id']}'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.serviceRequestAccent,
              backgroundColor: isSelected ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(120),
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTireAction = action['id'] as String);
                  sheetSetState(() {});
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(LocalizationService l) {
    if (_isLoadingCats) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Map<String, dynamic>> mappedCategories = [];
    for (final c in _dynamicCategories) {
      try {
        mappedCategories.add({
          'id': c['id']?.toString() ?? '',
          'label': _getCategoryName(c),
          'icon': c['icon_emoji'] ?? 'build',
          'iconImageUrl': c['icon_image_url'] as String?,
        });
      } catch (e) {
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    l.t('what_do_you_need'),
                    l.t('select_service_subtitle'),
                  ),
                  const SizedBox(height: 12),
                  if (mappedCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          l.t('no_services_available'),
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ServiceCategoryGridWidget(
                      categories: mappedCategories,
                      selectedId: _selectedCategory,
                      onSelected: _onCategorySelected,
                      crossAxisCount: 3,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final ts = ThemeService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ts.sectionTitleTextColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13, color: ts.sectionSubtitleTextColor),
        ),
      ],
    );
  }

  Widget _buildPopupSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.serviceRequestAccent,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ts = ThemeService.instance;
    final clipper = ServiceRequestPopupClipper();
    final path = clipper.getClip(size);

    // Outer wide glow
    final outerGlow = Paint()
      ..color = ts.serviceRequestPopupOutlineGlow.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(path, outerGlow);

    // Mid glow
    final midGlow = Paint()
      ..color = ts.serviceRequestPopupOutlineGlow.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, midGlow);

    // Sharp border
    final border = Paint()
      ..color = ts.serviceRequestPopupOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
