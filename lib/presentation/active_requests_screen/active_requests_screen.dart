import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service_request_screen/widgets/active_request_banner_widget.dart';
import '../service_request_screen/widgets/help_request_detail_sheet.dart';

class ActiveRequestsScreen extends StatefulWidget {
  const ActiveRequestsScreen({super.key});

  @override
  State<ActiveRequestsScreen> createState() => _ActiveRequestsScreenState();
}

class _ActiveRequestsScreenState extends State<ActiveRequestsScreen> {
  bool _isLoading = true;
  List<ActiveHelpRequest> _activeRequests = [];
  RealtimeChannel? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadActiveRequests();
  }

  @override
  void dispose() {
    _requestSubscription?.unsubscribe();
    _requestSubscription = null;
    super.dispose();
  }

  Future<void> _loadActiveRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.getActiveJobRequests();
      if (mounted) {
        setState(() => _activeRequests = data.map(_mapToActiveRequest).toList());
        _subscribeToRequests();
      }
    } catch (e) {
      if (mounted) setState(() => _activeRequests = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToRequests() {
    _requestSubscription?.unsubscribe();
    _requestSubscription = null;

    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;

    _requestSubscription = Supabase.instance.client
        .channel('customer_active_requests_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (payload) async {
            if (!mounted) return;
            // Small delay to let read replicas catch up
            await Future.delayed(const Duration(milliseconds: 300));
            await _loadActiveRequests();
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
      serviceIconImageUrl: data['service_icon_image_url'] as String?,
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
      fuelType: data['fuel_type'] as String?,
      fuelAmount: (data['fuel_amount'] as num?)?.toDouble(),
      tirePosition: data['tire_position'] as String?,
      tireAction: data['tire_action'] as String?,
      customerLat: (data['customer_lat'] as num?)?.toDouble(),
      customerLng: (data['customer_lng'] as num?)?.toDouble(),
      vehicleId: data['vehicle_id'] as String?,
      vehicleMake: data['vehicle_make'] as String?,
      vehicleModel: data['vehicle_model'] as String?,
      vehicleColor: data['vehicle_color'] as String?,
      vehicleYear: data['vehicle_year'] as String?,
      vehiclePlate: data['vehicle_plate'] as String?,
      vehicleType: data['vehicle_type'] as String?,
      vehicleSize: data['vehicle_size'] as String?,
    );
  }

  void _showRequestDetail(ActiveHelpRequest request) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: AppTheme.serviceRequestBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + 80,
        ),
        child: HelpRequestDetailSheet(
          request: request,
          onCancel: () => _cancelRequest(request),
          onQuoteAccepted: _loadActiveRequests,
          onRefresh: _loadActiveRequests,
        ),
      ),
    );
  }

  Future<void> _cancelRequest(ActiveHelpRequest request) async {
    final l = LocalizationService.instance;
    try {
      await SupabaseService.instance.cancelJobRequest(request.id);
      if (mounted) {
        await _loadActiveRequests();
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
    final ts = ThemeService.instance;
    final screenBg = ts.userScreenBgColor.withAlpha((255 * ts.userScreenBgOpacity).round());
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        title: Text(
          l.t('active_requests'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _activeRequests.isEmpty
              ? _buildEmptyState(l)
              : RefreshIndicator(
                  onRefresh: _loadActiveRequests,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 12,
                      bottom: MediaQuery.paddingOf(context).bottom + 80,
                    ),
                    itemCount: _activeRequests.length,
                    itemBuilder: (context, index) {
                      final request = _activeRequests[index];
                      return ActiveRequestBannerWidget(
                        request: request,
                        allowExpand: false,
                        onTap: () => _showRequestDetail(request),
                        onRefresh: _loadActiveRequests,
                        onCancel: () => _cancelRequest(request),
                      );
                    },
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
            color: Colors.white.withAlpha(180),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('no_active_requests'),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.t('no_active_requests_subtitle'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white.withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
