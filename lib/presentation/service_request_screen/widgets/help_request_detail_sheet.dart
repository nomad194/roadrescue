import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/notification_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './active_request_banner_widget.dart';

class HelpRequestDetailSheet extends StatefulWidget {
  final ActiveHelpRequest request;
  final VoidCallback onCancel;
  final VoidCallback? onQuoteAccepted;
  final VoidCallback? onRefresh;

  const HelpRequestDetailSheet({
    super.key,
    required this.request,
    required this.onCancel,
    this.onQuoteAccepted,
    this.onRefresh,
  });

  @override
  State<HelpRequestDetailSheet> createState() => _HelpRequestDetailSheetState();
}

class _HelpRequestDetailSheetState extends State<HelpRequestDetailSheet> {
  bool _acceptingQuote = false;
  bool _showPostPaymentForCash = false;
  bool _showPostPaymentForOnline = true;
  bool _whatsappEnabled = true;

  bool _providerAcceptsCash = true;
  bool _providerAcceptsOnline = true;

  bool get _isConfirmed =>
      widget.request.status == HelpRequestStatus.accepted ||
      widget.request.status == HelpRequestStatus.enRoute ||
      widget.request.status == HelpRequestStatus.awaitingConfirmation ||
      widget.request.status == HelpRequestStatus.awaitingReconfirmation ||
      widget.request.status == HelpRequestStatus.disputed;

  bool _isSubmittingResponse = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadProviderPaymentMethods();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value')
          .inFilter('setting_key', [
            'post_payment_screen_cash',
            'post_payment_screen_online',
            'whatsapp_chat_enabled',
          ]);
      for (final row in response as List) {
        if (!mounted) return;
        if (row['setting_key'] == 'post_payment_screen_cash') {
          setState(
            () => _showPostPaymentForCash = row['setting_value'] == 'true',
          );
        } else if (row['setting_key'] == 'post_payment_screen_online') {
          setState(
            () => _showPostPaymentForOnline = row['setting_value'] == 'true',
          );
        } else if (row['setting_key'] == 'whatsapp_chat_enabled') {
          setState(() => _whatsappEnabled = row['setting_value'] == 'true');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProviderPaymentMethods() async {
    try {
      // Get provider's accepted methods
      final response = await Supabase.instance.client
          .from('job_requests')
          .select('accepted_payment_methods')
          .eq('id', widget.request.id)
          .maybeSingle();
      if (response != null && mounted) {
        final methods =
            (response['accepted_payment_methods'] as String?) ?? 'cash,online';
        final providerAcceptsCash = methods.contains('cash');
        final providerAcceptsOnline = methods.contains('online');

        // Check globally enabled payment methods
        final globalMethods = await SupabaseService.instance.getPaymentMethods();
        final cashEnabledGlobally = globalMethods.any((m) => m['code'] == 'cash' && m['is_enabled'] == true);
        final onlineEnabledGlobally = globalMethods.any((m) => m['code'] == 'stripe' && m['is_enabled'] == true);

        setState(() {
          // Only show if provider accepts AND globally enabled
          _providerAcceptsCash = providerAcceptsCash && cashEnabledGlobally;
          _providerAcceptsOnline = providerAcceptsOnline && onlineEnabledGlobally;
        });
      }
    } catch (_) {}
  }

  void _acceptWithCOD() async {
    if (_acceptingQuote) return;
    setState(() => _acceptingQuote = true);
    final l = LocalizationService.instance;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await Supabase.instance.client
          .from('job_requests')
          .update({
            'job_status': 'confirmed',
            'payment_method_used': 'cash',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.request.id);

      await NotificationService.instance.showLocalNotification(
        title: l.t('quote_accepted_cod_notif'),
        body: l.t('quote_accepted_cod_notif_body'),
        payload: 'booking_confirmed_cod',
      );

      if (!mounted) return;
      widget.onQuoteAccepted?.call();
      nav.pop();

      if (_showPostPaymentForCash) {
        nav.pushNamed(
          AppRoutes.postPaymentScreen,
          arguments: {
            'amount': widget.request.quotedPrice ?? 0.0,
            'bookingId': widget.request.id,
            'serviceType': widget.request.serviceType,
            'providerName': widget.request.providerName ?? '',
            'providerBusiness': widget.request.providerBusiness ?? '',
            'providerPhone': widget.request.providerPhone ?? '',
            'paymentMethod': l.t('cash_on_delivery_payment'),
            'customerName': l.t('customer'),
          },
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l.t('order_confirmed_cod'),
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acceptingQuote = false);
        messenger.showSnackBar(
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

  void _acceptWithOnlinePayment() {
    final nav = Navigator.of(context);
    if (!mounted) return;
    nav.pop();
    nav.pushNamed(
      AppRoutes.paymentScreen,
      arguments: {
        'amount': widget.request.quotedPrice ?? 0.0,
        'bookingId': widget.request.id,
        'customerId': null,
        'providerId': null,
        'serviceType': widget.request.serviceType,
        'providerName': widget.request.providerName,
        'providerBusiness': widget.request.providerBusiness,
        'providerPhone': widget.request.providerPhone,
        'paymentMethod': 'Online',
        'showPostPaymentScreen': _showPostPaymentForOnline,
        'onPaymentSuccess': true,
      },
    );
  }

  void _openWhatsApp() {
    final l = LocalizationService.instance;
    final phone =
        widget.request.providerPhone?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
    final message = Uri.encodeComponent(
      l.t('whatsapp_message_template')
          .replaceAll('{name}', widget.request.providerName ?? 'there')
          .replaceAll('{id}', widget.request.id.substring(0, 8))
          .replaceAll('{service}', widget.request.serviceType)
          .replaceAll('{address}', widget.request.address),
    );
    final url = 'https://wa.me/$phone?text=$message';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.t('opening_whatsapp').replaceAll('{name}', widget.request.providerName ?? 'your provider'),
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l.t('active_request')} #${widget.request.id.substring(0, 8)}',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.request.serviceType,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(l),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.location_on_rounded,
                    AppTheme.error,
                    widget.request.address,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.description_outlined,
                    AppTheme.primary,
                    widget.request.description?.isNotEmpty == true
                        ? widget.request.description
                        : l.t('no_additional_details'),
                  ),
                  if (_isConfirmed && widget.request.providerName != null) ...[
                    const SizedBox(height: 20),
                    _buildProviderCard(l),
                  ],
                  if (widget.request.status == HelpRequestStatus.quoted &&
                      widget.request.providerName != null) ...[
                    const SizedBox(height: 20),
                    _buildQuotedProviderCard(l),
                  ],
                  if ((widget.request.status == HelpRequestStatus.quoted ||
                          _isConfirmed) &&
                      widget.request.quotedPrice != null) ...[
                    const SizedBox(height: 16),
                    _buildPriceRow(l),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    l.t('suggested_next_steps'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._nextSteps.asMap().entries.map(
                    (e) => _buildNextStepTile(
                      e.key + 1,
                      e.value['icon'] as IconData,
                      e.value['title'] as String,
                      e.value['desc'] as String,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.request.status == HelpRequestStatus.quoted &&
                      widget.request.quotedPrice != null) ...[
                    _buildPaymentMethodSelector(l),
                    const SizedBox(height: 12),
                  ],
                  if (_isConfirmed && _whatsappEnabled) ...[
                    _buildWhatsAppButton(l),
                    const SizedBox(height: 12),
                  ],

                  // ── SERVICE COMPLETION FLOW ────────────────────────────────────────
                  if (_isConfirmed && widget.request.status != HelpRequestStatus.disputed) ...[
                    _buildCompletionFlowUI(l),
                    const SizedBox(height: 12),
                  ],

                  // ── DISPUTE ALERT ───────────────────────────────────────────────
                  if (widget.request.status == HelpRequestStatus.disputed) ...[
                    _buildDisputeAlert(l),
                    const SizedBox(height: 12),
                  ],
                  if (widget.request.status == HelpRequestStatus.pending ||
                      widget.request.status == HelpRequestStatus.quoted)
                    _buildCancelButton(l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector(LocalizationService l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('choose_payment_method'),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.t('choose_payment_method_desc'),
          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        if (_providerAcceptsOnline) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _acceptingQuote ? null : _acceptWithOnlinePayment,
              icon: _acceptingQuote
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.credit_card_rounded, size: 20),
              label: Text(
                '${l.t('pay_online')} · \$${widget.request.quotedPrice!.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_providerAcceptsCash) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _acceptingQuote ? null : _acceptWithCOD,
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: Text(
                '${l.t('cash_on_delivery')} · \$${widget.request.quotedPrice!.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.success,
                side: BorderSide(color: AppTheme.success.withAlpha(150)),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
        if (!_providerAcceptsOnline && !_providerAcceptsCash) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.t('no_payment_methods'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> get _nextSteps {
    final l = LocalizationService.instance;
    switch (widget.request.status) {
      case HelpRequestStatus.pending:
        return [
          {
            'icon': Icons.wifi_tethering_rounded,
            'title': l.t('stay_connected'),
            'desc': l.t('stay_connected_desc'),
          },
          {
            'icon': Icons.location_on_rounded,
            'title': l.t('stay_at_location'),
            'desc': l.t('stay_at_location_desc'),
          },
          {
            'icon': Icons.notifications_active_rounded,
            'title': l.t('watch_for_quotes'),
            'desc': l.t('watch_for_quotes_desc'),
          },
          {
            'icon': Icons.security_rounded,
            'title': l.t('stay_safe'),
            'desc': l.t('stay_safe_desc'),
          },
        ];
      case HelpRequestStatus.quoted:
        return [
          {
            'icon': Icons.request_quote_rounded,
            'title': l.t('review_quote'),
            'desc': l.t('review_quote_desc'),
          },
          {
            'icon': Icons.payment_rounded,
            'title': l.t('choose_payment_method_step'),
            'desc': l.t('choose_payment_method_step_desc'),
          },
          {
            'icon': Icons.check_circle_outline_rounded,
            'title': l.t('confirm_booking'),
            'desc': l.t('confirm_booking_desc'),
          },
        ];
      case HelpRequestStatus.accepted:
        return [
          {
            'icon': Icons.hourglass_empty_rounded,
            'title': l.t('waiting_for_provider'),
            'desc': l.t('waiting_for_provider_desc'),
          },
          {
            'icon': Icons.chat_rounded,
            'title': l.t('chat_whatsapp'),
            'desc': l.t('chat_whatsapp_desc'),
          },
        ];
      case HelpRequestStatus.enRoute:
        return [
          {
            'icon': Icons.directions_car_rounded,
            'title': l.t('provider_on_way_step'),
            'desc': l.t('provider_on_way_step_desc').replaceAll('{eta}', widget.request.etaMinutes?.toString() ?? '—'),
          },
          {
            'icon': Icons.chat_rounded,
            'title': l.t('chat_whatsapp_button'),
            'desc': l.t('chat_whatsapp_button_desc'),
          },
          {
            'icon': Icons.location_on_rounded,
            'title': l.t('stay_visible'),
            'desc': l.t('stay_visible_desc'),
          },
        ];
      case HelpRequestStatus.cancelled:
        return [
          {
            'icon': Icons.refresh_rounded,
            'title': l.t('submit_new_request'),
            'desc': l.t('submit_new_request_desc'),
          },
        ];
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        return [
          {
            'icon': Icons.help_outline_rounded,
            'title': l.t('confirmation_needed'),
            'desc': l.t('confirmation_needed_desc'),
          },
        ];
      case HelpRequestStatus.disputed:
        return [
          {
            'icon': Icons.gavel_rounded,
            'title': l.t('job_under_review'),
            'desc': l.t('job_under_review_desc'),
          },
        ];
      case HelpRequestStatus.completed:
        return [
          {
            'icon': Icons.check_circle_rounded,
            'title': l.t('job_completed_step'),
            'desc': l.t('job_completed_step_desc'),
          },
        ];
    }
  }

  Widget _buildStatusChip(LocalizationService l) {
    Color color;
    String label;
    switch (widget.request.status) {
      case HelpRequestStatus.pending:
        color = AppTheme.warning;
        label = l.t('standard');
        break;
      case HelpRequestStatus.quoted:
        color = AppTheme.primary;
        label = l.t('quote_received');
        break;
      case HelpRequestStatus.accepted:
        color = Colors.orange;
        label = l.t('status_accepted');
        break;
      case HelpRequestStatus.enRoute:
        color = AppTheme.success;
        label = l.t('status_en_route');
        break;
      case HelpRequestStatus.awaitingConfirmation:
      case HelpRequestStatus.awaitingReconfirmation:
        color = AppTheme.secondary;
        label = l.t('status_reviewing');
        break;
      case HelpRequestStatus.disputed:
        color = AppTheme.error;
        label = l.t('status_disputed');
        break;
      case HelpRequestStatus.completed:
        color = AppTheme.success;
        label = l.t('status_done');
        break;
      case HelpRequestStatus.cancelled:
        color = AppTheme.muted;
        label = l.t('cancel_request');
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color iconColor, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuotedProviderCard(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withAlpha(40),
            backgroundImage: widget.request.providerImageUrl != null
                ? NetworkImage(widget.request.providerImageUrl!)
                : null,
            child: widget.request.providerImageUrl == null
                ? Icon(Icons.person_rounded, color: AppTheme.primary, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.providerName ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (widget.request.etaMinutes != null)
                  Text(
                    l.t('eta_min_step').replaceAll('{eta}', widget.request.etaMinutes.toString()),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('service_provider'),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.success.withAlpha(40),
                backgroundImage: widget.request.providerImageUrl != null
                    ? NetworkImage(widget.request.providerImageUrl!)
                    : null,
                child: widget.request.providerImageUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        color: AppTheme.success,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request.providerName ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (widget.request.providerBusiness != null)
                      Text(
                        widget.request.providerBusiness!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    if (widget.request.providerPhone != null)
                      Text(
                        widget.request.providerPhone!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.request.etaMinutes != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 5),
                Text(
                  l.t('eta_minutes_step').replaceAll('{eta}', widget.request.etaMinutes.toString()),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: 6),
          Text(
            _isConfirmed ? l.t('agreed_price') : l.t('quoted_price'),
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '\$${widget.request.quotedPrice!.toStringAsFixed(2)}',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepTile(
    int step,
    IconData icon,
    String title,
    String desc,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$step',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 5),
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton(LocalizationService l) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openWhatsApp,
        icon: const Icon(Icons.chat_rounded, size: 18),
        label: Text(
          l.t('chat_with_provider_whatsapp'),
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCancelButton(LocalizationService l) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          widget.onCancel();
        },
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: Text(
          l.t('cancel_request'),
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: BorderSide(color: AppTheme.error.withAlpha(120)),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ─── COMPLETION FLOW WIDGETS ─────────────────────────────────────────────

  Widget _buildCompletionFlowUI(LocalizationService l) {
    final status = widget.request.status;
    final bool hasVoted = widget.request.customerConfirmation != null;

    // If the customer has already voted, always show the waiting card
    if (hasVoted) {
      return _buildWaitingCard(l);
    }

    if (status == HelpRequestStatus.accepted || status == HelpRequestStatus.enRoute) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmittingResponse ? null : () => _submitResponse(true),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(l.t('mark_as_completed')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return _buildPromptCard(
      l,
      title: status == HelpRequestStatus.awaitingReconfirmation
          ? l.t('reconfirmation_required')
          : l.t('service_completed_question'),
      subtitle: status == HelpRequestStatus.awaitingReconfirmation
          ? l.t('provider_disagreed_prompt')
          : l.t('provider_marked_finished'),
    );
  }

  Widget _buildPromptCard(LocalizationService l, {required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(100), width: 2),
      ),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmittingResponse ? null : () => _submitResponse(false),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)),
                  child: Text(l.t('no_not_yet')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmittingResponse ? null : () => _submitResponse(true),
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

  Widget _buildWaitingCard(LocalizationService l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 12),
          Text(
            l.t('waiting_provider_confirmation'),
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeAlert(LocalizationService l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.errorContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error)),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('job_disputed'), style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AppTheme.error)),
                Text(l.t('job_disputed_description'), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResponse(bool confirmed) async {
    setState(() => _isSubmittingResponse = true);
    try {
      await SupabaseService.instance.submitCompletionResponse(
        requestId: widget.request.id,
        role: 'customer',
        confirmed: confirmed,
      );
      
      // Signal parent to reload data immediately
      widget.onRefresh?.call();

      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('response_submitted')),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = LocalizationService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.t('error')}: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingResponse = false);
    }
  }
}
