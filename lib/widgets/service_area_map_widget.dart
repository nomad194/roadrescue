import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ServiceAreaMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double serviceRange;
  final Function(double)? onRangeChanged;
  final Function(double)? onRangeChangeEnd;
  final Function(double lat, double lng)? onLocationChanged;
  final bool showSlider;
  final bool allowMarkerMove;
  final String distanceUnit; // 'mi' or 'km'

  const ServiceAreaMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.serviceRange,
    this.onRangeChanged,
    this.onRangeChangeEnd,
    this.onLocationChanged,
    this.showSlider = true,
    this.allowMarkerMove = true,
    this.distanceUnit = 'mi',
  });

  @override
  State<ServiceAreaMapWidget> createState() => _ServiceAreaMapWidgetState();
}

class _ServiceAreaMapWidgetState extends State<ServiceAreaMapWidget> {
  late LatLng _markerPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _markerPosition = LatLng(widget.latitude, widget.longitude);
  }

  @override
  void didUpdateWidget(ServiceAreaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update marker if external lat/lng changed significantly
    if ((widget.latitude - _markerPosition.latitude).abs() > 0.001 ||
        (widget.longitude - _markerPosition.longitude).abs() > 0.001) {
      setState(() {
        _markerPosition = LatLng(widget.latitude, widget.longitude);
      });
    }
  }

  void _updateMarkerPosition(LatLng newPosition) {
    setState(() {
      _markerPosition = newPosition;
    });
    // Notify parent of new location
    if (widget.onLocationChanged != null) {
      widget.onLocationChanged!(newPosition.latitude, newPosition.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Map Instructions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.allowMarkerMove 
                    ? 'Pan: Drag map | Zoom: Pinch | Move pin: Drag marker'
                    : 'Pan: Drag map | Zoom: Pinch',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Map Container
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _markerPosition,
              zoom: 12,
              interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              onTap: widget.allowMarkerMove ? (_, point) => _updateMarkerPosition(point) : null,
            ),
            children: [
              // OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.roadrescue.app',
              ),
              // Service Range Circle (centered on marker)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _markerPosition,
                    radius: _milesToMeters(widget.serviceRange),
                    color: AppTheme.primary.withOpacity(0.15),
                    borderColor: AppTheme.primary,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                  ),
                  // Inner circle for visual effect
                  CircleMarker(
                    point: _markerPosition,
                    radius: _milesToMeters(widget.serviceRange * 0.5),
                    color: AppTheme.primary.withOpacity(0.08),
                    borderColor: AppTheme.primary.withOpacity(0.5),
                    borderStrokeWidth: 1,
                    useRadiusInMeter: true,
                  ),
                ],
              ),
              // Provider Location Marker (draggable)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _markerPosition,
                    width: widget.allowMarkerMove ? 50 : 40,
                    height: widget.allowMarkerMove ? 50 : 40,
                    child: GestureDetector(
                      onPanUpdate: widget.allowMarkerMove ? (details) {
                        // Calculate new position based on drag
                        final pixelDelta = details.delta;
                        final zoom = _mapController.camera.zoom;
                        final scale = 60000 / (1 << zoom.toInt()); // Approximate meters per pixel
                        
                        final latDelta = -pixelDelta.dy * scale / 111320;
                        final lngDelta = pixelDelta.dx * scale / (111320 * cos(_markerPosition.latitude * pi / 180).abs());
                        
                        final newPosition = LatLng(
                          _markerPosition.latitude + latDelta,
                          _markerPosition.longitude + lngDelta,
                        );
                        
                        _updateMarkerPosition(newPosition);
                      } : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (widget.allowMarkerMove)
                              Container(
                                width: 20,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        if (widget.allowMarkerMove && widget.onLocationChanged != null) ...[
          const SizedBox(height: 8),
          Text(
            'Tap anywhere on map or drag marker to adjust location',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        
        if (widget.showSlider && widget.onRangeChanged != null) ...[
          const SizedBox(height: 16),
          // Range Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.serviceRange.toInt()} ${widget.distanceUnit == 'km' ? 'km' : 'miles'}',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Range Slider
          Slider(
            value: widget.serviceRange.clamp(5, 200),
            min: 5,
            max: 200,
            divisions: 39,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.primary.withOpacity(0.2),
            onChanged: widget.onRangeChanged,
            onChangeEnd: widget.onRangeChangeEnd,
          ),
          // Range Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '5 ${widget.distanceUnit == 'km' ? 'km' : 'mi'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  '100 ${widget.distanceUnit == 'km' ? 'km' : 'mi'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  '200 ${widget.distanceUnit == 'km' ? 'km' : 'mi'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drag slider to adjust your service area radius (${widget.distanceUnit == 'km' ? 'km' : 'miles'})',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  double _milesToMeters(double miles) {
    return miles * 1609.344;
  }
}
