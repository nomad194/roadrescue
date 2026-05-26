import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/language_selector_widget.dart';
import '../../widgets/service_area_map_widget.dart';
import '../../services/localization_service.dart';
import '../../services/supabase_service.dart';
import './widgets/provider_plan_purchase_dialog.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAvailable = true;
  bool _isLoadingGeo = true;
  bool _isUploadingAvatar = false;

  // Subscription
  Map<String, dynamic>? _activeSubscription;
  bool _isLoadingSubscription = true;
  String _subscriptionStatus = 'inactive'; // from provider_subscription_state

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessImageController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // Geo zone data
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  String? _selectedStateId;
  String? _selectedCityId;
  String _distanceUnit = 'mi'; // 'mi' or 'km'

  // Geocoding
  bool _isGeocoding = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadGeoData();
    _loadProviderGeoSettings();
    _loadDistanceUnit();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    
    setState(() => _isLoadingSubscription = true);
    try {
      // Load subscription state
      final subState = await SupabaseService.instance.getProviderSubscriptionState(userId);
      final subscription = await SupabaseService.instance.getProviderActiveSubscription(userId);
      if (mounted) {
        setState(() {
          _subscriptionStatus = subState['subscription_status'] as String? ?? 'inactive';
          _activeSubscription = subscription;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      if (mounted) setState(() => _isLoadingSubscription = false);
    }
  }

  void _showPlanPurchaseDialog() {
    final currentPlanId = _activeSubscription?['plan_id'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => ProviderPlanPurchaseDialog(currentPlanId: currentPlanId),
    ).then((_) => _loadSubscription());
  }

  Future<void> _loadDistanceUnit() async {
    try {
      final response = await SupabaseService.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'distance_unit')
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _distanceUnit = response['setting_value'] ?? 'mi';
        });
      }
    } catch (e) {
      debugPrint('Error loading distance unit: $e');
    }
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await SupabaseService.instance.getUserProfile(userId);
      if (profile != null && mounted) {
        debugPrint('Loading full profile - name: ${profile['full_name']}, address: ${profile['address']}');
        setState(() {
          _nameController.text = profile['full_name']?.toString() ?? '';
          _emailController.text = profile['email']?.toString() ?? '';
          _phoneController.text = profile['phone']?.toString() ?? '';
          _businessNameController.text = profile['business_name']?.toString() ?? '';
          _businessImageController.text = profile['avatar_url']?.toString() ?? '';
          _addressController.text = profile['address']?.toString() ?? '';
          _zipController.text = profile['zip_code']?.toString() ?? '';
          _latController.text = profile['address_lat']?.toString() ?? '';
          _lngController.text = profile['address_lng']?.toString() ?? '';
          _isAvailable = profile['is_available'] as bool? ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadGeoData() async {
    try {
      final states = await SupabaseService.instance.getStates();
      if (mounted) {
        setState(() {
          _states = states;
          _isLoadingGeo = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
      if (mounted) setState(() => _isLoadingGeo = false);
    }
  }

  Future<void> _loadCitiesForState(String stateId) async {
    try {
      final cities = await SupabaseService.instance.getCitiesByState(stateId);
      if (mounted) {
        setState(() {
          _cities = cities;
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    }
  }

  Future<void> _loadProviderGeoSettings() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await SupabaseService.instance.getUserProfile(userId);
      if (profile != null && mounted) {
        debugPrint('Loading geo settings - state: ${profile['selected_state_id']}, city: ${profile['selected_city_id']}');
        
        setState(() {
          _selectedStateId = profile['selected_state_id'] as String?;
          _selectedCityId = profile['selected_city_id'] as String?;
          
          if (_selectedStateId != null) {
            _loadCitiesForState(_selectedStateId!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading provider geo settings: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessImageController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  // Debounced geocoding when address or zip changes
  void _onAddressChanged(String value) {
    _triggerGeocoding();
  }

  void _onZipChanged(String value) {
    _triggerGeocoding();
  }

  void _triggerGeocoding() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    
    // Only geocode if we have both address (min 5 chars) and zip (min 3 chars)
    final address = _addressController.text.trim();
    final zip = _zipController.text.trim();
    
    if (address.length < 5 || zip.length < 3) return;
    
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _geocodeFullAddress();
    });
  }

  // Call OpenStreetMap API to geocode full address
  Future<void> _geocodeFullAddress() async {
    if (!_isEditing || _isGeocoding) return;
    
    setState(() => _isGeocoding = true);
    
    try {
      // Build full address query with street + city + state + zip + country
      final street = _addressController.text.trim();
      final zip = _zipController.text.trim();
      final city = _selectedCityId != null 
          ? _cities.firstWhere((c) => c['id'] == _selectedCityId, orElse: () => {'name': ''})['name'] 
          : '';
      final state = _selectedStateId != null 
          ? _states.firstWhere((s) => s['id'] == _selectedStateId, orElse: () => {'name': ''})['name'] 
          : '';
      
      // Build query: street, city, state, zip, Mexico
      final fullAddress = '$street, $city, $state, $zip, Mexico';
      final query = Uri.encodeComponent(fullAddress);
      
      debugPrint('Geocoding: $fullAddress');
      
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RoadRescueApp/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        if (data.isNotEmpty) {
          final result = data.first as Map<String, dynamic>;
          final lat = result['lat'] as String?;
          final lon = result['lon'] as String?;
          
          if (lat != null && lon != null) {
            setState(() {
              _latController.text = lat;
              _lngController.text = lon;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location found: $lat, $lon',
                  style: GoogleFonts.manrope(fontSize: 13),
                ),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Address not found. Try a more specific address.',
                style: GoogleFonts.manrope(fontSize: 13),
              ),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not find location. Please try again.',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
              title: Text('Take a Photo',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await SupabaseService.instance.uploadAvatar(userId, picked.path);
      await SupabaseService.instance.updateProfile(userId, {'avatar_url': url});
      if (mounted) {
        setState(() => _businessImageController.text = url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo updated!',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload photo: $e',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    final l = LocalizationService.instance;
    setState(() => _isSaving = true);
    
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) {
      setState(() => _isSaving = false);
      return;
    }
    
    try {
      // Save geo zone settings
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);
      final address = _addressController.text.trim();
      
      final zip = _zipController.text.trim();
      
      debugPrint('DEBUG: _addressController.text = "${_addressController.text}"');
      debugPrint('DEBUG: trimmed address = "$address"');
      debugPrint('DEBUG: zip = "$zip"');
      debugPrint('Saving profile - address: $address, zip: $zip, lat: $lat, lng: $lng');
      
      // Save geo zone settings
      await SupabaseService.instance.updateProviderGeoZone(
        providerId: userId,
        stateId: _selectedStateId,
        cityId: _selectedCityId,
        address: address.isNotEmpty ? address : null,
        zipCode: zip.isNotEmpty ? zip : null,
        addressLat: lat,
        addressLng: lng,
      );
      
      // Save main profile data (name, email, phone, business name, availability)
      await SupabaseService.instance.updateProfile(userId, {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'is_available': _isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Profile saved successfully');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t('profile_updated'),
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving profile: $e',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppTheme.onSurface,
          ),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.jobRequestsScreen,
            (r) => false,
          ),
        ),
        title: Text(
          l.t('my_profile'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        actions: [
          const LanguageSelectorWidget(),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _toggleEdit,
                        child: Text(
                          l.t('cancel'),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(70, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l.t('save'),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  )
                : IconButton(
                    onPressed: _toggleEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvailabilityBanner(l),
            const SizedBox(height: 16),
            _buildSubscriptionCard(l),
            const SizedBox(height: 16),
            _buildProfileHeader(l),
            const SizedBox(height: 16),
            _buildBusinessCard(l),
            const SizedBox(height: 16),
            _buildPersonalInfoCard(l),
            const SizedBox(height: 16),
            _buildStatsCard(l),
            const SizedBox(height: 16),
            _buildActionsCard(l),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBanner(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isAvailable
            ? AppTheme.successContainer
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isAvailable
              ? AppTheme.success.withAlpha(80)
              : AppTheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isAvailable ? AppTheme.success : AppTheme.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? l.t('available') : l.t('unavailable'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isAvailable
                        ? AppTheme.success
                        : AppTheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _isAvailable
                      ? l.t('customers_can_see_you')
                      : l.t('unavailable_info'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: _isAvailable ? AppTheme.success : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (v) {
              setState(() => _isAvailable = v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    v ? l.t('available_msg') : l.t('unavailable_msg'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: v
                      ? AppTheme.success
                      : AppTheme.onSurfaceVariant,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            activeThumbColor: AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(LocalizationService l) {
    if (_isLoadingSubscription) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasSubscription = _activeSubscription != null;
    final isPaused = _subscriptionStatus == 'paused';
    final isTrial = _subscriptionStatus == 'trial';
    final isActive = _subscriptionStatus == 'active' || isTrial;
    final planName = hasSubscription
        ? (_activeSubscription!['plan']?['name'] ?? 'Unknown Plan')
        : null;
    final expiresAt = hasSubscription
        ? DateTime.tryParse(_activeSubscription!['expires_at'] ?? '')
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    // Determine visual state
    final isGood = isActive && !isExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGood
            ? AppTheme.successContainer
            : AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGood
              ? AppTheme.success.withAlpha(80)
              : AppTheme.warning.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGood ? AppTheme.success : AppTheme.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGood
                      ? Icons.workspace_premium
                      : Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused
                          ? l.t('subscription_paused')
                          : isGood
                              ? l.t('active_subscription')
                              : isExpired
                                  ? l.t('subscription_expired')
                                  : l.t('no_active_subscription'),
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (hasSubscription && !isPaused) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$planName${expiresAt != null ? ' • ${l.t('expires')}: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      // Show trial badge
                      if (isTrial || (_activeSubscription?['admin_notes']?.toString().contains('Trial') ?? false))
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l.t('trial_period'),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Paused warning message
          if (isPaused || (isExpired && hasSubscription)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.t('subscription_paused_desc'),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPlanPurchaseDialog,
              icon: Icon(
                isGood ? Icons.refresh : Icons.upgrade,
                size: 18,
              ),
              label: Text(
                isGood ? l.t('renew_upgrade_plan') : l.t('subscribe_now'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGood
                    ? AppTheme.success
                    : AppTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primaryContainer,
                backgroundImage: _businessImageController.text.isNotEmpty
                    ? NetworkImage(_businessImageController.text) as ImageProvider
                    : null,
                onBackgroundImageError: _businessImageController.text.isNotEmpty
                    ? (_, __) {}
                    : null,
                child: _isUploadingAvatar
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : _businessImageController.text.isEmpty
                        ? Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : 'P',
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _nameController.text,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _businessNameController.text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.t('provider'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(LocalizationService l) {
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
          Text(
            l.t('business_info'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            Icons.business_outlined,
            l.t('business_name'),
            _businessNameController,
            l: l,
            enabled: _isEditing,
          ),
          _buildField(
            Icons.image_outlined,
            l.t('business_image_url'),
            _businessImageController,
            l: l,
            enabled: _isEditing,
            isLast: true,
          ),
          if (_isEditing && _businessImageController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _businessImageController.text,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(LocalizationService l) {
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
          Text(
            l.t('personal_info'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            Icons.person_outline,
            l.t('full_name'),
            _nameController,
            l: l,
            enabled: _isEditing,
          ),
          _buildField(
            Icons.email_outlined,
            l.t('email'),
            _emailController,
            l: l,
            enabled: _isEditing,
          ),
          _buildField(
            Icons.phone_outlined,
            l.t('phone'),
            _phoneController,
            l: l,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          _buildField(
            Icons.location_on_outlined,
            l.t('street_address'),
            _addressController,
            l: l,
            enabled: _isEditing,
            onChanged: _onAddressChanged,
            suffix: _isGeocoding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          ),
          _buildField(
            Icons.local_post_office_outlined,
            l.t('zip_code'),
            _zipController,
            l: l,
            enabled: _isEditing,
            onChanged: _onZipChanged,
            keyboardType: TextInputType.number,
          ),
          if (_isLoadingGeo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            const SizedBox(height: 14),
            Text(
              'Service Location',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            // State Dropdown
            DropdownButtonFormField<String>(
              value: _selectedStateId,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.map_outlined, size: 18, color: AppTheme.muted),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              hint: Text(
                'Select State',
                style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.muted),
              ),
              items: _states.map((s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text(
                  s['name'] as String,
                  style: GoogleFonts.manrope(fontSize: 14),
                ),
              )).toList(),
              onChanged: _isEditing ? (val) {
                setState(() {
                  _selectedStateId = val;
                  _selectedCityId = null;
                  _cities = [];
                });
                if (val != null) {
                  _loadCitiesForState(val);
                }
                // Trigger geocoding after state change
                _triggerGeocoding();
              } : null,
            ),
            const SizedBox(height: 12),
            // City Dropdown
            if (_selectedStateId != null)
              DropdownButtonFormField<String>(
                value: _selectedCityId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_city_outlined, size: 18, color: AppTheme.muted),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                hint: Text(
                  'Select City',
                  style: GoogleFonts.manrope(fontSize: 14, color: AppTheme.muted),
                ),
                items: _cities.map((c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(
                    c['name'] as String,
                    style: GoogleFonts.manrope(fontSize: 14),
                  ),
                )).toList(),
                onChanged: _isEditing ? (val) {
                  setState(() => _selectedCityId = val);
                  // Trigger geocoding after city change
                  _triggerGeocoding();
                } : null,
              ),
            const SizedBox(height: 14),
            Text(
              'Location Coordinates (for service range)',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            
            // Interactive Map for Location Adjustment
            if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)
              ServiceAreaMapWidget(
                latitude: double.tryParse(_latController.text) ?? 20.5,
                longitude: double.tryParse(_lngController.text) ?? -87.2,
                serviceRange: 25, // Default display range
                distanceUnit: _distanceUnit,
                showSlider: false, // No range slider on profile
                allowMarkerMove: _isEditing,
                onLocationChanged: _isEditing ? (lat, lng) {
                  setState(() {
                    _latController.text = lat.toString();
                    _lngController.text = lng.toString();
                  });
                } : null,
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Enter address and ZIP to see location on map',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    Icons.explore_outlined,
                    'Latitude (Auto)',
                    _latController,
                    l: l,
                    enabled: false, // Read-only, auto-populated
                    readOnly: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    Icons.explore_outlined,
                    'Longitude (Auto)',
                    _lngController,
                    l: l,
                    enabled: false, // Read-only, auto-populated
                    readOnly: true,
                    keyboardType: TextInputType.number,
                    isLast: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField(
    IconData icon,
    String label,
    TextEditingController controller, {
    required LocalizationService l,
    bool enabled = false,
    bool isLast = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          enabled
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  readOnly: readOnly,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 18, color: AppTheme.muted),
                    suffixIcon: suffix != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: suffix,
                        )
                      : null,
                    filled: true,
                    fillColor: readOnly ? AppTheme.surface.withAlpha(100) : AppTheme.surfaceVariant,
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
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: readOnly ? AppTheme.muted : AppTheme.onSurface,
                  ),
                )
              : Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.text.isEmpty
                            ? l.t('not_set')
                            : controller.text,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: controller.text.isEmpty
                              ? AppTheme.muted
                              : AppTheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LocalizationService l) {
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
          Text(
            l.t('performance'),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem(
                '47',
                l.t('jobs_done'),
                AppTheme.primary,
                AppTheme.primaryContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '4.9',
                l.t('rating'),
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
              const SizedBox(width: 10),
              _buildStatItem(
                '98%',
                l.t('accept_rate'),
                AppTheme.success,
                AppTheme.successContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    Color color,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 11, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(LocalizationService l) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildActionRow(
            Icons.history_outlined,
            l.t('service_history'),
            AppTheme.primary,
            () => Navigator.pushNamed(context, AppRoutes.serviceHistoryScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.card_membership,
            l.t('subscription_plans'),
            AppTheme.primary,
            _showPlanPurchaseDialog,
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.build_circle_outlined,
            l.t('my_services_pricing'),
            AppTheme.primary,
            () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.jobRequestsScreen,
              arguments: {'initialTabIndex': 1}, // Services tab
            ),
          ),
          _buildActionRow(
            Icons.description_outlined,
            l.t('required_documents'),
            AppTheme.primary,
            () => Navigator.pushNamed(context, AppRoutes.providerDocumentsScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.help_outline_rounded,
            l.t('faq'),
            AppTheme.primary,
            () => Navigator.pushNamed(context, AppRoutes.faqTosScreen),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.language,
            l.t('language'),
            AppTheme.primary,
            () => LanguageSelectorWidget.showLanguageDialog(context),
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.notifications_outlined,
            l.t('notifications'),
            AppTheme.primary,
            () {},
          ),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          _buildActionRow(
            Icons.logout_rounded,
            l.t('sign_out'),
            AppTheme.error,
            () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.signUpLoginScreen,
              (r) => false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color == AppTheme.error
                      ? AppTheme.error
                      : AppTheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
