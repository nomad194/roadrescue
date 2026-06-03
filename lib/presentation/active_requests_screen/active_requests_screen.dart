import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service_request_screen/widgets/active_request_banner_widget.dart';
import '../service_request_screen/widgets/help_request_detail_sheet.dart';
import 'package:roadrescue_shared/widgets/review_dialog_widget.dart';

class ActiveRequestsScreen extends StatefulWidget {
  const ActiveRequestsScreen({super.key});

  @override
  State<ActiveRequestsScreen> createState() => _ActiveRequestsScreenState();
}

class _ActiveRequestsScreenState extends State<ActiveRequestsScreen> {
  bool _isLoading = true;
  ActiveHelpRequest? _activeRequest;
  RealtimeChannel? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadActiveRequest();
  }

  @override
  void dispose() {
    _requestSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActiveRequest() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.getActiveJobRequest();
      if (mounted) {
        if (data != null) {
          final request = _mapToActiveRequest(data);
          setState(() => _activeRequest = request);
          _subscribeToRequest(data['id']?.toString() ?? '');
        } else {
          setState(() => _activeRequest = null);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _activeRequest = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToRequest(String jobId) {
    if (jobId.isEmpty) return;
    _requestSubscription?.unsubscribe();
    _requestSubscription = Supabase.instance.client
        .channel('active_request_$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (payload) async {
            if (!mounted) return;
            final updated = await SupabaseService.instance.getActiveJobRequest();
            if (mounted) {
              if (updated != null) {
                setState(() => _activeRequest = _mapToActiveRequest(updated));
              } else {
                setState(() => _activeRequest = null);
                _requestSubscription?.unsubscribe();
                _requestSubscription = null;
              }
            }
          },
        )
        .subscribe();
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
      submittedAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
      customerConfirmation: data['customer_confirmation'] as bool?,
      providerConfirmation: data['provider_confirmation'] as bool?,
      confirmationRound: data['confirmation_round'] as int? ?? 0,
      providerName: provider?['full_name'] as String?,
      providerPhone: provider?['phone'] as String?,
      providerBusiness: provider?['business_name'] as String?,
      providerImageUrl: provider?['avatar_url'] as String?,
      quotedPrice: data['quoted_price'] != null
          ? (data['quoted_price'] as num).toDouble()
          : null,
      etaMinutes: data['eta_minutes'] as int?,
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
    await _loadActiveRequest();
    if (_activeRequest == null && mounted) {
      final recentJob = await Supabase.instance.client
          .from('job_requests')
          .select('id, job_status')
          .eq('id', jobId)
          .maybeSingle();
      if (recentJob != null &&
          recentJob['job_status']?.toString() == 'completed' &&
          mounted) {
        ReviewDialogWidget.show(context, jobId, () {});
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
            content: Text(l.t('help_request_cancelled')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.t('generic_error')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
        title: Text(
          l.t('active_requests'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeRequest == null ||
                  _activeRequest!.status == HelpRequestStatus.completed ||
                  _activeRequest!.status == HelpRequestStatus.cancelled
              ? _buildEmptyState(l)
              : RefreshIndicator(
                  onRefresh: _loadActiveRequest,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ActiveRequestBannerWidget(
                          request: _activeRequest!,
                          onTap: _openRequestDetail,
                        ),
                        const SizedBox(height: 24),
                        _buildDetailCard(l),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(LocalizationService l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 16),
          Text(
            l.t('no_active_requests'),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.t('no_active_requests_subtitle'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppTheme.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(LocalizationService l) {
    final req = _activeRequest!;
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
            l.t('request_details'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(l.t('service_type'), req.serviceType),
          _buildDetailRow(l.t('address'), req.address),
          _buildDetailRow(l.t('description'), req.description),
          _buildDetailRow(l.t('urgency'),
              req.urgency == 'urgent' ? l.t('urgent') : l.t('standard')),
          if (req.providerName != null) ...[
            const Divider(height: 24, color: AppTheme.outlineVariant),
            Text(
              l.t('provider_info'),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(l.t('provider_name'), req.providerName!),
            if (req.providerBusiness != null)
              _buildDetailRow(l.t('business_name'), req.providerBusiness!),
            if (req.quotedPrice != null)
              _buildDetailRow(l.t('quoted_price'), '\$${req.quotedPrice!.toStringAsFixed(2)}'),
            if (req.etaMinutes != null)
              _buildDetailRow(l.t('eta'), '${req.etaMinutes} ${l.t('minutes')}'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    _fetch();
    _listen();
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await Supabase.instance.client
          .from('job_requests')
          .select(
              '*, provider:provider_id(full_name, phone, business_name, avatar_url)')
          .eq('id', widget.requestId)
          .maybeSingle();
      if (!mounted || data == null) return;

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

      setState(() {
        _req = ActiveHelpRequest(
          id: data['id']?.toString() ?? '',
          serviceType: data['service_type'] as String? ?? '',
          serviceIcon: data['service_icon'] as String? ?? 'build',
          address: data['address'] as String? ?? '',
          description: data['description'] as String? ?? '',
          urgency: data['urgency'] as String? ?? 'standard',
          status: status,
          submittedAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
              DateTime.now(),
          customerConfirmation: data['customer_confirmation'] as bool?,
          providerConfirmation: data['provider_confirmation'] as bool?,
          confirmationRound: data['confirmation_round'] as int? ?? 0,
          providerName: provider?['full_name'] as String?,
          providerPhone: provider?['phone'] as String?,
          providerBusiness: provider?['business_name'] as String?,
          providerImageUrl: provider?['avatar_url'] as String?,
          quotedPrice: data['quoted_price'] != null
              ? (data['quoted_price'] as num).toDouble()
              : null,
          etaMinutes: data['eta_minutes'] as int?,
        );
      });
    } catch (e) {
    }
  }

  void _listen() {
    _sub = Supabase.instance.client
        .channel('active_req_detail_${widget.requestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.requestId,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_req == null) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return HelpRequestDetailSheet(
      request: _req!,
      onCancel: widget.onCancel,
    );
  }
}
