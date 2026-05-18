import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_image_widget.dart';
import '../../../services/supabase_service.dart';
import '../../../services/localization_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/map_utils.dart';

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

  final bool? customerConfirmation;
  final bool? providerConfirmation;
  final int confirmationRound;

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
    this.customerConfirmation,
    this.providerConfirmation,
    this.confirmationRound = 0,
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
  bool _isSubmittingResponse = false;
  String _distanceUnit = 'mi';

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    try {
      final res = await Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'distance_unit')
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _distanceUnit = res['setting_value'] ?? 'mi');
      }
    } catch (_) {}
  }

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
    MapUtils.openGoogleMaps(widget.job.address);
  }

  Future<void> _submitCompletionResponse(bool confirmed) async {
    setState(() => _isSubmittingResponse = true);
    try {
      await SupabaseService.instance.submitCompletionResponse(
        requestId: widget.job.id,
        role: 'provider',
        confirmed: confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response submitted successfully'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.onStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSubmittingResponse = false);
  }

  Widget _buildProviderCompletionPrompt(LocalizationService l) {
    final bool isReconfirm = widget.job.status == 'awaiting_reconfirmation';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(80), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            isReconfirm ? "⚠️ Dispute Resolution" : "Has the service been completed?",
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            isReconfirm ? "Customer disagreed. Please confirm again." : "Confirm you have finished the work.",
            style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallActionButton(
                  label: "No",
                  color: AppTheme.error,
                  onTap: () => _submitCompletionResponse(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallActionButton(
                  label: "Yes",
                  color: AppTheme.success,
                  onTap: () => _submitCompletionResponse(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeAlert(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.errorContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error)),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: AppTheme.error, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Job Disputed. Admin has been notified.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.job.urgency == 'urgent';
    final serviceColor = _serviceColor(widget.job.serviceType);
    final isConfirmed =
        widget.job.status == 'accepted' || widget.job.status == 'confirmed' ||
        widget.job.status == 'awaiting_confirmation' ||
        widget.job.status == 'awaiting_reconfirmation';
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
                    Flexible(
                      child: Text(
                        widget.job.id,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            _distanceUnit,
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
                    Expanded(child: _buildStatusBadge(l)),
                    const SizedBox(width: 8),
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
                  ],
                ),
                const SizedBox(height: 12),
                // Action Buttons Wrap (Fixes overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!widget.job.quoteSent)
                      _ActionButton(
                        label: l.t('send_quote'),
                        icon: Icons.send_rounded,
                        color: Theme.of(context).primaryColor,
                        onTap: widget.onSendQuote,
                      )
                    else if (isConfirmed)
                      _ActionButton(
                        label: _markingEnRoute ? l.t('loading') : l.t('on_my_way'),
                        icon: _markingEnRoute ? Icons.hourglass_empty_rounded : Icons.directions_car_rounded,
                        color: const Color(0xFF0891B2),
                        onTap: _markingEnRoute ? () {} : _onMyWay,
                      )
                    else if (isEnRoute)
                      _ActionButton(
                        label: l.t('navigate'),
                        icon: Icons.navigation_rounded,
                        color: AppTheme.success,
                        onTap: _openNavigation,
                      ),

                    // ── Completion Flow Trigger ──
                    if ((isEnRoute || isConfirmed) && widget.job.providerConfirmation == null)
                      _ActionButton(
                        label: _isSubmittingResponse ? '...' : 'Done',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppTheme.success,
                        onTap: _isSubmittingResponse ? () {} : () => _submitCompletionResponse(true),
                      ),
                  ],
                ),

                // ── Completion Prompts (Mismatches) ──
                if ((widget.job.status == 'awaiting_confirmation' || widget.job.status == 'awaiting_reconfirmation') && 
                    widget.job.providerConfirmation == null && 
                    widget.job.customerConfirmation != null) ...[
                  const SizedBox(height: 12),
                  _buildProviderCompletionPrompt(l),
                ],

                // ── Dispute Alert ──
                if (widget.job.status == 'disputed') ...[
                  const SizedBox(height: 12),
                  _buildDisputeAlert(l),
                ],

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

  Widget _buildStatusBadge(LocalizationService l) {
    Color color;
    String label;

    switch (widget.job.status) {
      case 'quoted':
        color = Theme.of(context).primaryColor;
        label = l.t('quoted').toUpperCase();
        break;
      case 'accepted':
      case 'confirmed':
        color = AppTheme.success;
        label = l.t('active').toUpperCase();
        break;
      case 'awaiting_confirmation':
        color = AppTheme.secondary;
        label = "PENDING CONFIRMATION";
        break;
      case 'awaiting_reconfirmation':
        color = AppTheme.warning;
        label = "RE-CONFIRMING";
        break;
      case 'en_route':
        color = const Color(0xFF0891B2);
        label = 'EN ROUTE';
        break;
      case 'completed':
        color = AppTheme.success;
        label = 'DONE';
        break;
      case 'cancelled':
        color = AppTheme.error;
        label = 'CANCELLED';
        break;
      default:
        color = AppTheme.warning;
        label = l.t('new_jobs').split(' ')[0].toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
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
              Expanded(
                child: Text(
                  l.t('en_route_info'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                  onTap: () => MapUtils.openAppleMaps(widget.job.address),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
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
