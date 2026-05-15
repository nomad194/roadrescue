import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_image_widget.dart';
import '../../../services/supabase_service.dart';
import '../../../services/localization_service.dart';
import '../../../services/notification_service.dart';

class JobRequest {
  final String id;
  final String serviceType;
  final String serviceIcon;
  final String urgency;
  final String driverName;
  final String driverImageUrl;
  final String driverImageSemanticLabel;
  final String address;
  final double distanceMiles;
  final String description;
  final double estimatedValue;
  final String status;
  final bool quoteSent;
  final int postedMinutesAgo;

  const JobRequest({
    required this.id,
    required this.serviceType,
    required this.serviceIcon,
    required this.urgency,
    required this.driverName,
    required this.driverImageUrl,
    required this.driverImageSemanticLabel,
    required this.address,
    required this.distanceMiles,
    required this.description,
    required this.estimatedValue,
    required this.status,
    required this.quoteSent,
    required this.postedMinutesAgo,
  });
}

class JobRequestCardWidget extends StatefulWidget {
  final JobRequest job;
  final VoidCallback onSendQuote;
  final VoidCallback? onStatusChanged;

  const JobRequestCardWidget({
    super.key,
    required this.job,
    required this.onSendQuote,
    this.onStatusChanged,
  });

  @override
  State<JobRequestCardWidget> createState() => _JobRequestCardWidgetState();
}

class _JobRequestCardWidgetState extends State<JobRequestCardWidget> {
  bool _isExpanded = false;
  bool _markingEnRoute = false;

  IconData _iconFromString(String name) {
    switch (name) {
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'tire_repair':
        return Icons.tire_repair_rounded;
      case 'lock_open':
        return Icons.lock_open_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'battery_alert':
        return Icons.battery_alert_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  Color _serviceColor(String type) {
    switch (type.toLowerCase()) {
      case 'towing':
        return const Color(0xFF7C3AED);
      case 'flat tire':
        return const Color(0xFFD97706);
      case 'lockout':
        return const Color(0xFF0891B2);
      case 'fuel delivery':
        return const Color(0xFF16A34A);
      case 'jump start':
        return const Color(0xFFDC2626);
      case 'battery':
        return const Color(0xFF1A56DB);
      default:
        return AppTheme.primary;
    }
  }

  Future<void> _onMyWay() async {
    if (_markingEnRoute) return;
    setState(() => _markingEnRoute = true);
    final l = LocalizationService.instance;
    try {
      await SupabaseService.instance.markEnRoute(widget.job.id);
      // Notify customer that provider is on the way
      await NotificationService.instance.notifyCustomerEnRoute(
        SupabaseService.instance.currentUser?.userMetadata?['full_name']
                as String? ??
            'Your provider',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('status_updated_en_route'),
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
        widget.onStatusChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _markingEnRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.t('generic_error'),
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
    }
  }

  void _openNavigation() {
    final encodedAddress = Uri.encodeComponent(widget.job.address);
    // Google Maps URL — works on both Android and iOS
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening navigation to ${widget.job.address}...',
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () => debugPrint('Navigate to: $googleMapsUrl'),
        ),
      ),
    );
    debugPrint('Navigation URL: $googleMapsUrl');
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.job.urgency == 'urgent';
    final serviceColor = _serviceColor(widget.job.serviceType);
    final isConfirmed =
        widget.job.status == 'accepted' || widget.job.status == 'confirmed';
    final isEnRoute = widget.job.status == 'en_route';
    final l = LocalizationService.instance;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppTheme.error.withAlpha(77)
              : AppTheme.outlineVariant,
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Urgent indicator bar
          if (isUrgent)
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: service badge + job ID + time + urgency
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconFromString(widget.job.serviceIcon),
                            size: 13,
                            color: serviceColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.job.serviceType,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: serviceColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.job.id,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.priority_high_rounded,
                              size: 11,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              l.t('urgent_urgency').toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.error,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.job.postedMinutesAgo}m ago',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Driver info row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomImageWidget(
                        imageUrl: widget.job.driverImageUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        semanticLabel: widget.job.driverImageSemanticLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.job.driverName,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.job.address,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Distance badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${widget.job.distanceMiles}',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            l.t('miles'),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Description snippet
                Text(
                  widget.job.description,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Bottom row: estimated value + status + action
                Row(
                  children: [
                    // Estimated value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Est. Value',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: AppTheme.muted,
                          ),
                        ),
                        Text(
                          '\$${widget.job.estimatedValue.toStringAsFixed(0)}',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.success,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(l),
                    const Spacer(),
                    // Expand toggle
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action button
                    if (!widget.job.quoteSent)
                      _ActionButton(
                        label: l.t('send_quote'),
                        icon: Icons.send_rounded,
                        color: AppTheme.primary,
                        onTap: widget.onSendQuote,
                      )
                    else if (isConfirmed)
                      _ActionButton(
                        label: _markingEnRoute ? l.t('loading') : l.t('on_my_way'),
                        icon: _markingEnRoute
                            ? Icons.hourglass_empty_rounded
                            : Icons.directions_car_rounded,
                        color: const Color(0xFF0891B2),
                        onTap: _markingEnRoute ? () {} : _onMyWay,
                      )
                    else if (isEnRoute)
                      _ActionButton(
                        label: l.t('navigate'),
                        icon: Icons.navigation_rounded,
                        color: AppTheme.success,
                        onTap: _openNavigation,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.t('quote_sent_notif'),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── On My Way expanded section (shown when confirmed) ──
                if (isConfirmed && _isExpanded) ...[
                  const SizedBox(height: 12),
                  _buildOnMyWayBanner(l),
                ],

                // ── En Route navigation section ──
                if (isEnRoute && _isExpanded) ...[
                  const SizedBox(height: 12),
                  _buildEnRouteBanner(l),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnMyWayBanner(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0891B2).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0891B2).withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF0891B2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap "${l.t('on_my_way')}" to notify the customer and unlock GPS navigation.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: const Color(0xFF0891B2),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnRouteBanner(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.navigation_rounded,
                size: 16,
                color: AppTheme.success,
              ),
              const SizedBox(width: 8),
              Text(
                l.t('en_route_info'),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NavButton(
                  label: 'Google Maps',
                  icon: Icons.map_rounded,
                  color: AppTheme.primary,
                  onTap: _openNavigation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NavButton(
                  label: 'Apple Maps',
                  icon: Icons.directions_rounded,
                  color: const Color(0xFF0891B2),
                  onTap: () {
                    final encodedAddress = Uri.encodeComponent(
                      widget.job.address,
                    );
                    final appleMapsUrl =
                        'https://maps.apple.com/?daddr=$encodedAddress&dirflg=d';
                    debugPrint('Apple Maps URL: $appleMapsUrl');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Opening Apple Maps...',
                          style: TextStyle(fontSize: 13),
                        ),
                        backgroundColor: const Color(0xFF0891B2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(LocalizationService l) {
    Color color;
    Color bgColor;
    String label;

    switch (widget.job.status) {
      case 'new':
        color = AppTheme.warning;
        bgColor = AppTheme.warningContainer;
        label = 'New Request';
        break;
      case 'quoted':
        color = AppTheme.primary;
        bgColor = AppTheme.primaryContainer;
        label = l.t('quote_sent_notif');
        break;
      case 'accepted':
      case 'confirmed':
        color = AppTheme.success;
        bgColor = AppTheme.successContainer;
        label = l.t('booking_confirmed');
        break;
      case 'en_route':
        color = const Color(0xFF0891B2);
        bgColor = const Color(0xFF0891B2).withAlpha(25);
        label = 'En Route';
        break;
      case 'completed':
        color = AppTheme.muted;
        bgColor = AppTheme.surfaceVariant;
        label = l.t('done');
        break;
      default:
        color = AppTheme.muted;
        bgColor = AppTheme.surfaceVariant;
        label = widget.job.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
