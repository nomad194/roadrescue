import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/widgets/review_dialog_widget.dart';

/// Represents the state of an active help request
enum HelpRequestStatus {
  pending, // submitted, waiting for provider response
  quoted, // provider sent a quote, awaiting customer acceptance
  accepted, // customer accepted (DB: accepted or confirmed)
  enRoute, // provider is moving (DB: en_route or in_progress)
  awaitingConfirmation, // initial completion request sent
  awaitingReconfirmation, // disagreement round
  disputed, // persistent disagreement
  completed, // fully finished
  cancelled,
}

extension HelpRequestStatusExtension on HelpRequestStatus {
  /// Chat is available once a job is confirmed and active.
  /// This includes all post-quoting, pre-completion statuses.
  bool get isChatEnabled {
    return this == HelpRequestStatus.accepted ||
        this == HelpRequestStatus.enRoute ||
        this == HelpRequestStatus.awaitingConfirmation ||
        this == HelpRequestStatus.awaitingReconfirmation ||
        this == HelpRequestStatus.disputed;
  }

  /// Chat becomes read-only once the job is done, cancelled, or under persistent dispute.
  bool get isChatReadOnly {
    return this == HelpRequestStatus.completed ||
        this == HelpRequestStatus.cancelled ||
        this == HelpRequestStatus.disputed;
  }
}

class ActiveHelpRequest {
  final String id;
  final String serviceType;
  final String serviceIcon;
  final String? serviceIconImageUrl;
  final String address;
  final String description;
  final String urgency;
  final HelpRequestStatus status;
  final DateTime submittedAt;

  // Confirmation state
  final bool? customerConfirmation;
  final bool? providerConfirmation;
  final int confirmationRound;

  // Provider details — only populated once confirmed
  final String? providerName;
  final String? providerPhone; // E.164 format for WhatsApp
  final String? providerBusiness;
  final String? providerImageUrl;
  final double? quotedPrice;
  final int? etaMinutes;

  // Service-specific fields
  final String? fuelType;
  final double? fuelAmount;
  final String? tirePosition;
  final String? tireAction;

  // Location
  final double? customerLat;
  final double? customerLng;

  // Vehicle fields
  final String? vehicleId;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleYear;
  final String? vehiclePlate;
  final String? vehicleType;
  final String? vehicleSize;

  const ActiveHelpRequest({
    required this.id,
    required this.serviceType,
    required this.serviceIcon,
    this.serviceIconImageUrl,
    required this.address,
    required this.description,
    required this.urgency,
    required this.status,
    required this.submittedAt,
    this.customerConfirmation,
    this.providerConfirmation,
    this.confirmationRound = 0,
    this.providerName,
    this.providerPhone,
    this.providerBusiness,
    this.providerImageUrl,
    this.quotedPrice,
    this.etaMinutes,
    this.fuelType,
    this.fuelAmount,
    this.tirePosition,
    this.tireAction,
    this.customerLat,
    this.customerLng,
    this.vehicleId,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.vehiclePlate,
    this.vehicleType,
    this.vehicleSize,
  });

  ActiveHelpRequest copyWith({
    String? id,
    String? serviceType,
    String? serviceIcon,
    String? serviceIconImageUrl,
    String? address,
    String? description,
    String? urgency,
    HelpRequestStatus? status,
    DateTime? submittedAt,
    bool? customerConfirmation,
    bool? providerConfirmation,
    int? confirmationRound,
    String? providerName,
    String? providerPhone,
    String? providerBusiness,
    String? providerImageUrl,
    double? quotedPrice,
    int? etaMinutes,
    String? fuelType,
    double? fuelAmount,
    String? tirePosition,
    String? tireAction,
    double? customerLat,
    double? customerLng,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? vehiclePlate,
    String? vehicleType,
    String? vehicleSize,
  }) {
    return ActiveHelpRequest(
      id: id ?? this.id,
      serviceType: serviceType ?? this.serviceType,
      serviceIcon: serviceIcon ?? this.serviceIcon,
      serviceIconImageUrl: serviceIconImageUrl ?? this.serviceIconImageUrl,
      address: address ?? this.address,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      customerConfirmation: customerConfirmation ?? this.customerConfirmation,
      providerConfirmation: providerConfirmation ?? this.providerConfirmation,
      confirmationRound: confirmationRound ?? this.confirmationRound,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      providerBusiness: providerBusiness ?? this.providerBusiness,
      providerImageUrl: providerImageUrl ?? this.providerImageUrl,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      fuelType: fuelType ?? this.fuelType,
      fuelAmount: fuelAmount ?? this.fuelAmount,
      tirePosition: tirePosition ?? this.tirePosition,
      tireAction: tireAction ?? this.tireAction,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleSize: vehicleSize ?? this.vehicleSize,
    );
  }
}

class ActiveRequestBannerWidget extends StatefulWidget {
  final ActiveHelpRequest request;
  final VoidCallback? onTap;
  final bool allowExpand;
  final VoidCallback? onRefresh;
  final VoidCallback? onCancel;

  const ActiveRequestBannerWidget({
    super.key,
    required this.request,
    this.onTap,
    this.allowExpand = false,
    this.onRefresh,
    this.onCancel,
  });

  @override
  State<ActiveRequestBannerWidget> createState() => _ActiveRequestBannerWidgetState();
}

class _ActiveRequestBannerWidgetState extends State<ActiveRequestBannerWidget> {
  bool _isExpanded = false;
  bool _isMapExpanded = false;
  bool _isSubmittingResponse = false;

  ActiveHelpRequest get request => widget.request;

  @override
  void didUpdateWidget(covariant ActiveRequestBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _isExpanded = false;
      _isMapExpanded = false;
    }
  }

  Color get _statusColor {
    switch (request.status) {
      case HelpRequestStatus.pending:
        return AppTheme.warning;
      case HelpRequestStatus.quoted:
        return AppTheme.primary;
      case HelpRequestStatus.accepted:
        return Colors.orange;
      case HelpRequestStatus.enRoute:
        return AppTheme.success;
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        return AppTheme.secondary;
      case HelpRequestStatus.disputed:
        return AppTheme.error;
      case HelpRequestStatus.completed:
        return AppTheme.success;
      case HelpRequestStatus.cancelled:
        return AppTheme.muted;
    }
  }

  String get _statusLabel {
    final l = LocalizationService.instance;
    switch (request.status) {
      case HelpRequestStatus.pending:
        return l.t('searching_providers');
      case HelpRequestStatus.quoted:
        return l.t('quote_received');
      case HelpRequestStatus.accepted:
        return l.t('status_waiting_provider');
      case HelpRequestStatus.enRoute:
        return l.t('provider_on_way');
      case HelpRequestStatus.awaitingConfirmation:
        return request.customerConfirmation == true ? l.t('status_waiting_provider_short') : l.t('status_completion_requested');
      case HelpRequestStatus.awaitingReconfirmation:
        return l.t('status_confirm_completion');
      case HelpRequestStatus.disputed:
        return l.t('status_job_disputed');
      case HelpRequestStatus.completed:
        return l.t('status_job_completed');
      case HelpRequestStatus.cancelled:
        return l.t('cancel_request');
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case HelpRequestStatus.pending:
        return Icons.search_rounded;
      case HelpRequestStatus.quoted:
        return Icons.request_quote_rounded;
      case HelpRequestStatus.accepted:
        return Icons.access_time_rounded;
      case HelpRequestStatus.enRoute:
        return Icons.directions_car_rounded;
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        return Icons.help_outline_rounded;
      case HelpRequestStatus.disputed:
        return Icons.gavel_rounded;
      case HelpRequestStatus.completed:
        return Icons.check_circle_rounded;
      case HelpRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }


  @override
  Widget build(BuildContext context) {
    // If completed, don't show the banner anymore
    if (request.status == HelpRequestStatus.completed) {
      return const SizedBox.shrink();
    }

    final l = LocalizationService.instance;
    return GestureDetector(
      onTap: widget.allowExpand
          ? () => setState(() => _isExpanded = !_isExpanded)
          : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _statusColor.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _statusColor.withAlpha(80), width: 1.5),
        ),
        child: (widget.allowExpand && _isExpanded)
            ? _buildExpandedContent(l)
            : _buildCompactContent(l),
      ),
    );
  }

  Widget _buildCompactContent(LocalizationService l) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_statusIcon, color: _statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    request.serviceType,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      request.urgency == 'urgent'
                          ? '🚨 ${l.t('urgent_urgency')}'
                          : l.t('standard_urgency'),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _statusLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                request.address,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: Colors.white.withAlpha(180),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: _statusColor, size: 22),
      ],
    );
  }

  Widget _buildExpandedContent(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_statusIcon, color: _statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.serviceType,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_less_rounded, color: _statusColor, size: 22),
          ],
        ),
        const SizedBox(height: 12),
        // Location map
        _buildLocationMap(request),
        if (request.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDetailRow(Icons.description_outlined, request.description),
        ],
        // Gas Service details
        if (request.fuelType != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.local_gas_station_rounded,
            request.fuelAmount != null
              ? '${l.t('fuel_type_${request.fuelType}')} · \$${request.fuelAmount! % 1 == 0 ? request.fuelAmount!.toInt() : request.fuelAmount}'
              : l.t('fuel_type_${request.fuelType}'),
          ),
        ],
        // Flat Tire details
        if (request.tirePosition != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.tire_repair_rounded,
            '${l.t('tire_position_${request.tirePosition}')} · ${l.t('tire_action_${request.tireAction}')}',
          ),
        ],
        // Vehicle details
        if (request.vehicleMake != null || request.vehicleType != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.directions_car_rounded,
            _formatVehicle(request),
          ),
        ],
        // Provider info if available
        if (request.providerName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('service_provider'),
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _statusColor.withAlpha(30),
                      backgroundImage: request.providerImageUrl != null
                          ? NetworkImage(request.providerImageUrl!)
                          : null,
                      child: request.providerImageUrl == null
                          ? Icon(Icons.person_rounded, color: _statusColor, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.providerName!,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (request.providerPhone != null)
                            Text(
                              request.providerPhone!,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (request.etaMinutes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        l.t('eta_minutes_step').replaceAll('{eta}', request.etaMinutes.toString()),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        // Price if quoted
        if (request.quotedPrice != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money_rounded, color: AppTheme.serviceRequestAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  request.status == HelpRequestStatus.quoted
                      ? l.t('quoted_price')
                      : l.t('agreed_price'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${request.quotedPrice!.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.serviceRequestAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
        // ── Completion flow for awaiting_confirmation / awaiting_reconfirmation ──
        if (request.status == HelpRequestStatus.awaitingConfirmation ||
            request.status == HelpRequestStatus.awaitingReconfirmation ||
            request.status == HelpRequestStatus.accepted ||
            request.status == HelpRequestStatus.enRoute) ...[
          const SizedBox(height: 12),
          _buildCompletionSection(l),
        ],
        // ── Dispute alert ──
        if (request.status == HelpRequestStatus.disputed) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('job_disputed'), style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppTheme.error, fontSize: 13)),
                      Text(l.t('job_disputed_description'), style: GoogleFonts.manrope(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // ── Cancel button for pending/quoted ──
        if (request.status == HelpRequestStatus.pending ||
            request.status == HelpRequestStatus.quoted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
              label: Text(
                l.t('cancel_request'),
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.error.withAlpha(120)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionSection(LocalizationService l) {
    final status = request.status;
    final hasVoted = request.customerConfirmation != null;

    if (hasVoted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: 10),
            Text(
              l.t('waiting_provider_confirmation'),
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    if (status == HelpRequestStatus.accepted || status == HelpRequestStatus.enRoute) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmittingResponse ? null : () => _submitCompletionResponse(true),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(l.t('mark_as_completed')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final isReconfirm = status == HelpRequestStatus.awaitingReconfirmation;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(100), width: 2),
      ),
      child: Column(
        children: [
          Text(
            isReconfirm ? l.t('reconfirmation_required') : l.t('service_completed_question'),
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            isReconfirm ? l.t('provider_disagreed_prompt') : l.t('provider_marked_finished'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmittingResponse ? null : () => _submitCompletionResponse(false),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)),
                  child: Text(l.t('no_not_yet')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmittingResponse ? null : () => _submitCompletionResponse(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                  child: Text(l.t('yes_completed')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitCompletionResponse(bool confirmed) async {
    setState(() => _isSubmittingResponse = true);
    try {
      final newStatus = await SupabaseService.instance.submitCompletionResponse(
        requestId: request.id,
        role: 'customer',
        confirmed: confirmed,
      );
      widget.onRefresh?.call();
      if (mounted && newStatus == 'completed') {
        ReviewDialogWidget.show(context, request.id, widget.onRefresh ?? () {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.instance.t('response_submitted')),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService.instance.t('error')}: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingResponse = false);
    }
  }

  Widget _buildLocationMap(ActiveHelpRequest request) {
    final hasCoords = request.customerLat != null && request.customerLng != null;
    final lat = request.customerLat ?? 20.5;
    final lng = request.customerLng ?? -87.2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    if (hasCoords)
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 17,
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
                                point: LatLng(lat, lng),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.serviceRequestAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 6),
                                    ],
                                  ),
                                  child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Container(
                        color: Colors.white.withAlpha(15),
                        child: Center(
                          child: Icon(Icons.map_outlined, color: Colors.white.withAlpha(80), size: 40),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_rounded, size: 13, color: AppTheme.serviceRequestAccent),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                request.address,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white.withAlpha(200),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white.withAlpha(180)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white.withAlpha(200),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatVehicle(ActiveHelpRequest request) {
    final l = LocalizationService.instance;
    final parts = <String>[];
    if (request.vehicleType != null && request.vehicleType!.isNotEmpty) parts.add(l.t('vehicle_size_${request.vehicleType}'));
    if (request.vehicleMake != null && request.vehicleMake!.isNotEmpty) parts.add(request.vehicleMake!);
    if (request.vehicleModel != null && request.vehicleModel!.isNotEmpty) parts.add(request.vehicleModel!);
    if (request.vehicleColor != null && request.vehicleColor!.isNotEmpty) parts.add(l.t(request.vehicleColor!));
    if (request.vehicleYear != null && request.vehicleYear!.isNotEmpty) parts.add(request.vehicleYear!);
    if (request.vehiclePlate != null && request.vehiclePlate!.isNotEmpty) parts.add('(${request.vehiclePlate})');
    if (parts.isEmpty && request.vehicleSize?.isNotEmpty == true) return request.vehicleSize!;
    return parts.join(' ');
  }
}
