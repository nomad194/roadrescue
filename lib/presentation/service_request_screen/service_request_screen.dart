import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../../routes/app_routes.dart';
import '../../config/app_constants.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import './widgets/location_card_widget.dart';
import './widgets/request_form_widget.dart';
import './widgets/request_submit_button_widget.dart';
import './widgets/service_category_grid_widget.dart';
import './widgets/active_request_banner_widget.dart';
import './widgets/help_request_detail_sheet.dart';
import '../../widgets/review_dialog_widget.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({super.key});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  String? _selectedCategory;
  String? _selectedVehicleSize;
  String _urgencyLevel = 'standard';
  bool _isSubmitting = false;

  // GPS location state
  double? _locationLat;
  double? _locationLng;
  String? _locationAddress;

  // Active help request state (backed by real DB)
  ActiveHelpRequest? _activeRequest;
  RealtimeChannel? _requestSubscription;

  List<Map<String, dynamic>> _dynamicCategories = [];
  bool _isLoadingCats = true;

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadActiveRequest(), _loadCategories()]);
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _isLoadingCats = false;
        });
      }
    }
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
          debugPrint('Active request loaded: ${request.id} - ${request.status}');
        } else {
          // Explicitly clear if no active request found
          setState(() => _activeRequest = null);
          debugPrint('No active request found.');
        }
      }
    } catch (e) {
      debugPrint('Error loading active request: $e');
    }
  }

  void _subscribeToRequest(String requestId) {
    _requestSubscription?.unsubscribe();
    _requestSubscription = SupabaseService.instance.subscribeToJobRequest(
      requestId,
      (record) async {
        if (!mounted) return;
        
        // 1. Re-fetch full record with joins
        final updated = await SupabaseService.instance.getActiveJobRequest();
        
        if (mounted) {
          if (updated != null) {
            // Still active, update data
            setState(() => _activeRequest = _mapToActiveRequest(updated));
          } else {
            // Not found in "Active" filter (means it's completed or cancelled)
            // Check if it was completed (not cancelled) to show review dialog
            final completedJobId = _activeRequest?.id;
            final wasCompleted = record['job_status'] == 'completed';
            setState(() => _activeRequest = null);
            _requestSubscription?.unsubscribe();
            _requestSubscription = null;
            if (wasCompleted && completedJobId != null && mounted) {
              await Future.delayed(const Duration(milliseconds: 400));
              if (mounted) {
                ReviewDialogWidget.show(context, completedJobId, () {});
              }
            }
          }
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
      serviceType: data['service_type'] as String? ?? '',
      serviceIcon: data['service_icon'] as String? ?? 'build',
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
    );
  }

  void _onCategorySelected(String id) {
    setState(() {
      _selectedCategory = id;
      _selectedVehicleSize = null;
    });
  }

  void _onUrgencyChanged(String level) {
    setState(() => _urgencyLevel = level);
  }

  Future<void> _onSubmit() async {
    final l = LocalizationService.instance;
    if (_selectedCategory == null) {
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
    if (_availableVehicleSizes.isNotEmpty && _selectedVehicleSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t('vehicle_size_subtitle'),
            style: GoogleFonts.manrope(fontSize: 14),
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final cat = _dynamicCategories.firstWhere(
        (c) => c['id'].toString() == _selectedCategory,
        orElse: () => {'icon_emoji': 'build'},
      );
      final serviceIcon = cat['icon_emoji'] ?? 'build';

      final data = await SupabaseService.instance.createJobRequest(
        serviceType: _selectedCategoryLabel,
        serviceIcon: serviceIcon,
        vehicleSize: _selectedVehicleSize ?? '',
        address: _locationAddress ?? '',
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : l.t('no_additional_details'),
        urgency: _urgencyLevel,
        customerLat: _locationLat,
        customerLng: _locationLng,
      );

      final newRequest = _mapToActiveRequest(data);
      setState(() {
        _activeRequest = newRequest;
        _selectedCategory = null;
        _selectedVehicleSize = null;
        _descriptionController.clear();
      });

      _subscribeToRequest(data['id']?.toString() ?? '');
      _showRequestSubmittedDialog(data['id']?.toString() ?? '');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('generic_error'),
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

  void _showRequestSubmittedDialog(String requestId) {
    final l = LocalizationService.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                color: AppTheme.onSurfaceVariant,
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
                      l.t('whatsapp_info_after_confirm'),
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

  void _openRequestDetail() async {
    if (_activeRequest == null) return;
    final jobId = _activeRequest!.id;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActiveRequestDetailWrapper(
        onCancel: _cancelRequest,
        requestId: jobId,
      ),
    );
    
    // When the sheet is closed, re-fetch to see if it completed
    await _loadActiveRequest();
    
    // If no longer active, check if it completed — show review dialog
    if (_activeRequest == null && mounted) {
      final recentJob = await Supabase.instance.client
          .from('job_requests')
          .select('id, job_status')
          .eq('id', jobId)
          .maybeSingle();
      if (recentJob != null && recentJob['job_status'] == 'completed' && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) ReviewDialogWidget.show(context, jobId, () {});
      }
    }
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
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signUpLoginScreen,
        (r) => false,
      );
    }
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
        title: Text(
          l.t('request_help'),
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.customerProfileScreen),
            icon: const Icon(
              Icons.person_outline_rounded,
              size: 22,
              color: AppTheme.primary,
            ),
            tooltip: l.t('my_profile'),
            visualDensity: VisualDensity.compact,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.jobRequestsScreen,
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
                      Icons.work_outline_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Provider',
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
            if (_activeRequest != null &&
                _activeRequest!.status != HelpRequestStatus.cancelled)
              ActiveRequestBannerWidget(
                request: _activeRequest!,
                onTap: _openRequestDetail,
              ),
            Expanded(
              child: _isTablet ? _buildTabletLayout(l) : _buildPhoneLayout(l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(LocalizationService l) {
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
        });
      } catch (e) {
        debugPrint('Error mapping category: $e');
      }
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocationCardWidget(
              onLocationDetected: (lat, lng, address) {
                setState(() {
                  _locationLat = lat;
                  _locationLng = lng;
                  _locationAddress = address;
                });
              },
            ),
            const SizedBox(height: 20),
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
                crossAxisCount: 2,
              ),
            if (_selectedCategory != null &&
                _availableVehicleSizes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildVehicleSizePicker(l),
            ],
            const SizedBox(height: 20),
            RequestFormWidget(
              controller: _descriptionController,
              urgencyLevel: _urgencyLevel,
              onUrgencyChanged: _onUrgencyChanged,
            ),
            const SizedBox(height: 24),
            RequestSubmitButtonWidget(
              isSubmitting: _isSubmitting,
              isEnabled: _selectedCategory != null,
              onSubmit: _onSubmit,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSizePicker(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l.t('vehicle_size'), l.t('vehicle_size_subtitle')),
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
                onTap: () => setState(
                  () => _selectedVehicleSize = vehicle['id'] as String,
                ),
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
                              ? Colors.white
                              : AppTheme.onSurfaceVariant,
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
        });
      } catch (e) {
        debugPrint('Error mapping category: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
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
                  if (_selectedCategory != null &&
                      _availableVehicleSizes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildVehicleSizePicker(l),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LocationCardWidget(
                    onLocationDetected: (lat, lng, address) {
                      setState(() {
                        _locationLat = lat;
                        _locationLng = lng;
                        _locationAddress = address;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  RequestFormWidget(
                    controller: _descriptionController,
                    urgencyLevel: _urgencyLevel,
                    onUrgencyChanged: _onUrgencyChanged,
                  ),
                  const SizedBox(height: 20),
                  RequestSubmitButtonWidget(
                    isSubmitting: _isSubmitting,
                    isEnabled: _selectedCategory != null,
                    onSubmit: _onSubmit,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
        ),
      ],
    );
  }
}

// ─── INTERNAL WRAPPER TO ENSURE BOTTOM SHEET REFRESHES ──────────────────────

class _ActiveRequestDetailWrapper extends StatefulWidget {
  final String requestId;
  final VoidCallback onCancel;

  const _ActiveRequestDetailWrapper({
    required this.requestId,
    required this.onCancel,
  });

  @override
  State<_ActiveRequestDetailWrapper> createState() =>
      _ActiveRequestDetailWrapperState();
}

class _ActiveRequestDetailWrapperState
    extends State<_ActiveRequestDetailWrapper> {
  RealtimeChannel? _sub;
  ActiveHelpRequest? _req;

  @override
  void initState() {
    super.initState();
    _load();
    
    // Explicitly listen to ALL changes on this row
    _sub = Supabase.instance.client
        .channel('sheet_sync:${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Query the SPECIFIC request ID, including completed ones
      final data = await Supabase.instance.client
          .from('job_requests')
          .select('*, provider:provider_id(id, full_name, phone, business_name, avatar_url)')
          .eq('id', widget.requestId)
          .maybeSingle();

      if (data == null && mounted) {
        Navigator.pop(context);
        return;
      }

      // Final check for mounted and non-null data
      if (data != null && mounted) {
        final statusStr = data['job_status'] as String? ?? 'pending';
        
        // If completed, close sheet immediately
        if (statusStr == 'completed') {
          Navigator.pop(context);
          return;
        }

        final provider = data['provider'] as Map<String, dynamic>?;
        HelpRequestStatus status;
        switch (statusStr) {
          case 'quoted': status = HelpRequestStatus.quoted; break;
          case 'accepted':
          case 'confirmed':
            status = HelpRequestStatus.accepted; break;
          case 'en_route':
          case 'in_progress':
            status = HelpRequestStatus.enRoute; break;
          case 'awaiting_confirmation': status = HelpRequestStatus.awaitingConfirmation; break;
          case 'awaiting_reconfirmation': status = HelpRequestStatus.awaitingReconfirmation; break;
          case 'disputed': status = HelpRequestStatus.disputed; break;
          case 'cancelled': status = HelpRequestStatus.cancelled; break;
          default: status = HelpRequestStatus.pending;
        }

        setState(() {
          _req = ActiveHelpRequest(
            id: data['id']?.toString() ?? '',
            serviceType: data['service_type'] as String? ?? '',
            serviceIcon: data['service_icon'] as String? ?? 'build',
            address: data['address'] as String? ?? '',
            description: data['description'] as String? ?? '',
            urgency: data['urgency'] as String? ?? 'standard',
            status: status,
            submittedAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
            customerConfirmation: data['customer_confirmation'] as bool?,
            providerConfirmation: data['provider_confirmation'] as bool?,
            confirmationRound: (data['confirmation_round'] as num?)?.toInt() ?? 0,
            providerName: provider?['full_name'] as String?,
            providerPhone: provider?['phone'] as String?,
            providerBusiness: provider?['business_name'] as String?,
            providerImageUrl: provider?['avatar_url'] as String?,
            quotedPrice: (data['quoted_price'] as num?)?.toDouble(),
            etaMinutes: (data['eta_minutes'] as num?)?.toInt(),
          );
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_req == null) return const Center(child: CircularProgressIndicator());

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => HelpRequestDetailSheet(
        request: _req!,
        onCancel: widget.onCancel,
        onRefresh: _load,
      ),
    );
  }
}
