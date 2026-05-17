import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';

/// Represents the state of an active help request
enum HelpRequestStatus {
  pending, // submitted, waiting for provider response
  quoted, // provider sent a quote, awaiting customer acceptance
  confirmed, // customer accepted / booking confirmed
  awaitingConfirmation, // initial completion request sent
  awaitingReconfirmation, // disagreement round
  disputed, // persistent disagreement
  cancelled,
}

class ActiveHelpRequest {
  final String id;
  final String serviceType;
  final String serviceIcon;
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

  const ActiveHelpRequest({
    required this.id,
    required this.serviceType,
    required this.serviceIcon,
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
  });
}

class ActiveRequestBannerWidget extends StatelessWidget {
  final ActiveHelpRequest request;
  final VoidCallback onTap;

  const ActiveRequestBannerWidget({
    super.key,
    required this.request,
    required this.onTap,
  });

  Color get _statusColor {
    switch (request.status) {
      case HelpRequestStatus.pending:
        return AppTheme.warning;
      case HelpRequestStatus.quoted:
        return AppTheme.primary;
      case HelpRequestStatus.confirmed:
        return AppTheme.success;
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        return AppTheme.secondary;
      case HelpRequestStatus.disputed:
        return AppTheme.error;
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
      case HelpRequestStatus.confirmed:
        return l.t('provider_on_way');
      case HelpRequestStatus.awaitingConfirmation:
        return "Completion Requested";
      case HelpRequestStatus.awaitingReconfirmation:
        return "Confirm Completion";
      case HelpRequestStatus.disputed:
        return "Job Disputed";
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
      case HelpRequestStatus.confirmed:
        return Icons.directions_car_rounded;
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        return Icons.help_outline_rounded;
      case HelpRequestStatus.disputed:
        return Icons.gavel_rounded;
      case HelpRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _statusColor.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _statusColor.withAlpha(80), width: 1.5),
        ),
        child: Row(
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
                          color: AppTheme.onSurface,
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
                      color: AppTheme.muted,
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
        ),
      ),
    );
  }
}
