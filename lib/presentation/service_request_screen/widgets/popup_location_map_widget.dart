import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/location_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';

/// Self-contained map + street name widget for the service request popup.
/// Handles its own GPS acquisition so it updates correctly inside a dialog.
class PopupLocationMapWidget extends StatefulWidget {
  final double height;
  final Function(double lat, double lng, String address)? onLocationDetected;

  const PopupLocationMapWidget({
    super.key,
    this.height = 120,
    this.onLocationDetected,
  });

  @override
  State<PopupLocationMapWidget> createState() => _PopupLocationMapWidgetState();
}

class _PopupLocationMapWidgetState extends State<PopupLocationMapWidget> {
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _acquireLocation();
  }

  Future<void> _acquireLocation() async {
    final cached = await LocationService.getLastKnownLocation();
    if (cached != null) {
      final lat = cached['lat'] as double?;
      final lng = cached['lng'] as double?;
      final addr = cached['address'] as String? ?? '';
      if (mounted && lat != null && lng != null) {
        setState(() {
          _latitude = lat;
          _longitude = lng;
          _address = addr;
          _isLoading = false;
        });
        widget.onLocationDetected?.call(lat, lng, addr);
      }
      return;
    }

    await _fetchFreshLocation();
  }

  Future<void> _forceRefresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await LocationService.clearCachedLocation();
    await _fetchFreshLocation();
  }

  Future<void> _fetchFreshLocation() async {
    final permission = await LocationService.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final position = await LocationService.getCurrentPosition(
      timeout: const Duration(seconds: 8),
    );
    if (position == null || !mounted) {
      if (mounted) setState(() => _isLoading = false);
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
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = resolvedAddress;
        _isLoading = false;
      });
      widget.onLocationDetected?.call(
        position.latitude,
        position.longitude,
        resolvedAddress,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;

    if (_isLoading || _latitude == null || _longitude == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.serviceRequestBorder),
            ),
            child: Text(
              l.t('detecting_location'),
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.white.withAlpha(180),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.t('detecting_location'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white.withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final streetName = _address?.split(',').first.trim() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map
        Container(
          height: widget.height,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.serviceRequestBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
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
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Refresh button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _forceRefresh,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Street name
        Text(
          streetName,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.white.withAlpha(180),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
