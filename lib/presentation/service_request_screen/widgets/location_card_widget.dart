import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/location_service.dart';

class LocationCardWidget extends StatefulWidget {
  final Function(double lat, double lng, String address)? onLocationDetected;
  
  const LocationCardWidget({super.key, this.onLocationDetected});

  @override
  State<LocationCardWidget> createState() => _LocationCardWidgetState();
}

class _LocationCardWidgetState extends State<LocationCardWidget>
    with SingleTickerProviderStateMixin {
  // Location state
  bool _isDetecting = false;
  bool _hasLocation = false;
  bool _showTimeoutError = false;
  bool _showPermissionError = false;
  bool _showManualInput = false;
  bool _isPoorAccuracy = false;
  
  // Location data
  double? _latitude;
  double? _longitude;
  String _address = '';
  double _accuracy = 0;
  
  // Manual input
  final TextEditingController _manualAddressController = TextEditingController();
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Load cached location on init; auto-acquire GPS if none cached
    _loadCachedLocation();
  }

  Future<void> _loadCachedLocation() async {
    final cached = await LocationService.getLastKnownLocation();
    if (cached != null && mounted) {
      setState(() {
        _latitude = cached['lat'];
        _longitude = cached['lng'];
        _address = cached['address'];
        _hasLocation = true;
      });
      // Notify parent
      widget.onLocationDetected?.call(_latitude!, _longitude!, _address);
    } else {
      // No cached location — auto-acquire GPS
      await _acquireLocation();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }
  
  Future<void> _acquireLocation() async {
    setState(() {
      _isDetecting = true;
      _showTimeoutError = false;
      _showPermissionError = false;
      _showManualInput = false;
    });
    
    // Check permission first
    final permission = await LocationService.requestPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      setState(() {
        _isDetecting = false;
        _showPermissionError = true;
        _showManualInput = true;
      });
      return;
    }
    
    // Get GPS position with 10s timeout
    final position = await LocationService.getCurrentPosition(
      timeout: const Duration(seconds: 10),
    );
    
    if (position == null) {
      // Timeout or other error
      setState(() {
        _isDetecting = false;
        _showTimeoutError = true;
        _showManualInput = true;
      });
      return;
    }
    
    // Check accuracy
    final isPoorAccuracy = LocationService.isAccuracyPoor(position);
    
    // Reverse geocode to get address
    final address = await LocationService.reverseGeocode(
      position.latitude, 
      position.longitude,
    );
    
    if (mounted) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
        _address = address ?? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _hasLocation = true;
        _isDetecting = false;
        _isPoorAccuracy = isPoorAccuracy;
      });
      
      // Cache the location
      await LocationService.saveLastKnownLocation(
        position.latitude, 
        position.longitude, 
        _address,
      );
      
      // Notify parent
      widget.onLocationDetected?.call(_latitude!, _longitude!, _address);
    }
  }
  
  Future<void> _useManualAddress() async {
    final address = _manualAddressController.text.trim();
    if (address.isEmpty) return;
    
    setState(() => _isDetecting = true);
    
    final coords = await LocationService.geocodeAddress(address);
    
    if (coords != null && mounted) {
      setState(() {
        _latitude = coords['lat'];
        _longitude = coords['lng'];
        _address = address;
        _hasLocation = true;
        _isDetecting = false;
        _showManualInput = false;
        _isPoorAccuracy = false;
      });
      
      // Cache the location
      await LocationService.saveLastKnownLocation(
        _latitude!, 
        _longitude!, 
        _address,
      );
      
      // Notify parent
      widget.onLocationDetected?.call(_latitude!, _longitude!, _address);
    } else {
      setState(() => _isDetecting = false);
      // Show error
      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('could_not_geocode'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main location card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDetecting
                  ? AppTheme.primary.withAlpha(102)
                  : _isPoorAccuracy
                      ? AppTheme.warning.withAlpha(102)
                      : AppTheme.outlineVariant,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // GPS icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isDetecting
                              ? AppTheme.primary.withValues(
                                  alpha: 0.1 * _pulseAnimation.value + 0.05,
                                )
                              : _isPoorAccuracy
                                  ? AppTheme.warningContainer
                                  : AppTheme.successContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isDetecting
                              ? Icons.gps_not_fixed_rounded
                              : _isPoorAccuracy
                                  ? Icons.gps_off_rounded
                                  : Icons.gps_fixed_rounded,
                          size: 22,
                          color: _isDetecting
                              ? AppTheme.primary
                              : _isPoorAccuracy
                                  ? AppTheme.warning
                                  : AppTheme.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  
                  // Location info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDetecting
                              ? l.t('detecting_location')
                              : _hasLocation
                                  ? l.t('location_confirmed')
                                  : l.t('location_not_set'),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isDetecting
                                ? AppTheme.primary
                                : _isPoorAccuracy
                                    ? AppTheme.warning
                                    : AppTheme.success,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isDetecting
                              ? l.t('gps_acquiring')
                              : _hasLocation
                                  ? _address
                                  : l.t('tap_use_location'),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_hasLocation && !_isDetecting) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_latitude!.toStringAsFixed(4)}°N, ${_longitude!.toStringAsFixed(4)}°W · Accuracy: ±${_accuracy.toStringAsFixed(0)}m',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.muted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  if (!_isDetecting) ...[
                    if (_hasLocation)
                      TextButton.icon(
                        onPressed: _acquireLocation,
                        icon: const Icon(Icons.refresh, size: 16),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        label: Text(
                          l.t('gps_refresh'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 140,
                        child: ElevatedButton.icon(
                          onPressed: _acquireLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: Text(
                            l.t('gps_use_my_location'),
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              
              // Poor accuracy warning
              if (_isPoorAccuracy && !_isDetecting) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.t('gps_poor_accuracy').replaceAll('{accuracy}', _accuracy.toStringAsFixed(0)),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Timeout error
              if (_showTimeoutError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.t('gps_timeout'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Permission error
              if (_showPermissionError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_off, color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.t('gps_permission_denied'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Manual address input (fallback)
        if (_showManualInput) ...[
          const SizedBox(height: 16),
          Container(
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
                  l.t('enter_address_manually'),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualAddressController,
                  decoration: InputDecoration(
                    hintText: l.t('enter_street_address'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant.withAlpha(128),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _useManualAddress,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      l.t('use_this_address'),
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Map preview (when location is available)
        if (_hasLocation && _latitude != null && _longitude != null) ...[
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_latitude!, _longitude!),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.roadrescue.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_latitude!, _longitude!),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
