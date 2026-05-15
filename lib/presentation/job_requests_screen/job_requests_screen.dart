import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import './widgets/job_filter_bar_widget.dart';
import './widgets/job_request_card_widget.dart';
import './widgets/provider_stats_header_widget.dart';
import './widgets/quote_bottom_sheet_widget.dart';

class JobRequestsScreen extends StatefulWidget {
  const JobRequestsScreen({super.key});

  @override
  State<JobRequestsScreen> createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _selectedStatusFilter = 'new';

  late AnimationController _listController;
  RealtimeChannel? _jobSubscription;

  List<_JobRequest> _jobs = [];

  List<_JobRequest> get _filteredJobs {
    return _jobs.where((job) {
      final matchesService =
          _selectedFilter == 'all' ||
          job.serviceType.toLowerCase().replaceAll(' ', '_') ==
              _selectedFilter.toLowerCase().replaceAll(' ', '_');
      final matchesStatus =
          _selectedStatusFilter == 'all' || job.status == _selectedStatusFilter;
      return matchesService && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadJobs();
    _subscribeToJobUpdates();
  }

  @override
  void dispose() {
    _listController.dispose();
    _jobSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.getProviderJobRequests();
      if (mounted) {
        setState(() {
          _jobs = data.map(_mapToJobRequest).toList();
          _isLoading = false;
        });
        _listController.reset();
        _listController.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToJobUpdates() {
    _jobSubscription = SupabaseService.instance.subscribeToJobRequestUpdates((
      record,
    ) {
      if (!mounted) return;
      final updatedJob = _mapToJobRequestFromRecord(record);
      setState(() {
        final idx = _jobs.indexWhere((j) => j.id == updatedJob.id);
        if (idx != -1) {
          _jobs[idx] = updatedJob;
        } else {
          // New job inserted — reload full list for customer join data
          _loadJobs();
        }
      });
    });
  }

  _JobRequest _mapToJobRequest(Map<String, dynamic> data) {
    final customer = data['customer'] as Map<String, dynamic>?;
    final statusStr = data['job_status'] as String? ?? 'pending';
    final mappedStatus = _mapStatus(statusStr);

    return _JobRequest(
      id: data['id'] as String,
      serviceType: data['service_type'] as String? ?? '',
      serviceIcon: data['service_icon'] as String? ?? 'build',
      driverName: customer?['full_name'] as String? ?? 'Unknown Customer',
      driverPhone: customer?['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      distanceMiles: 2.5,
      description: data['description'] as String? ?? '',
      postedMinutesAgo: _minutesAgo(data['created_at'] as String?),
      urgency: data['urgency'] as String? ?? 'standard',
      status: mappedStatus,
      estimatedValue: (data['quoted_price'] as num?)?.toDouble() ?? 0.0,
      quoteSent: data['quoted_price'] != null,
      driverImageUrl:
          customer?['avatar_url'] as String? ??
          'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg',
      driverImageSemanticLabel: 'Customer profile photo',
    );
  }

  _JobRequest _mapToJobRequestFromRecord(Map<String, dynamic> record) {
    final statusStr = record['job_status'] as String? ?? 'pending';
    final mappedStatus = _mapStatus(statusStr);
    // Find existing job to preserve customer data
    final existing = _jobs.firstWhere(
      (j) => j.id == record['id'],
      orElse: () => _JobRequest(
        id: record['id'] as String? ?? '',
        serviceType: record['service_type'] as String? ?? '',
        serviceIcon: record['service_icon'] as String? ?? 'build',
        driverName: 'Customer',
        driverPhone: '',
        address: record['address'] as String? ?? '',
        distanceMiles: 2.5,
        description: record['description'] as String? ?? '',
        postedMinutesAgo: _minutesAgo(record['created_at'] as String?),
        urgency: record['urgency'] as String? ?? 'standard',
        status: mappedStatus,
        estimatedValue: (record['quoted_price'] as num?)?.toDouble() ?? 0.0,
        quoteSent: record['quoted_price'] != null,
        driverImageUrl:
            'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg',
        driverImageSemanticLabel: 'Customer profile photo',
      ),
    );

    return _JobRequest(
      id: existing.id,
      serviceType: record['service_type'] as String? ?? existing.serviceType,
      serviceIcon: record['service_icon'] as String? ?? existing.serviceIcon,
      driverName: existing.driverName,
      driverPhone: existing.driverPhone,
      address: record['address'] as String? ?? existing.address,
      distanceMiles: existing.distanceMiles,
      description: record['description'] as String? ?? existing.description,
      postedMinutesAgo: existing.postedMinutesAgo,
      urgency: record['urgency'] as String? ?? existing.urgency,
      status: mappedStatus,
      estimatedValue:
          (record['quoted_price'] as num?)?.toDouble() ??
          existing.estimatedValue,
      quoteSent: record['quoted_price'] != null,
      driverImageUrl: existing.driverImageUrl,
      driverImageSemanticLabel: existing.driverImageSemanticLabel,
    );
  }

  String _mapStatus(String dbStatus) {
    switch (dbStatus) {
      case 'quoted':
        return 'quoted';
      case 'accepted':
      case 'confirmed':
        return 'accepted';
      case 'en_route':
        return 'en_route';
      case 'in_progress':
        return 'accepted';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'new';
    }
  }

  int _minutesAgo(String? isoString) {
    if (isoString == null) return 0;
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 0;
    return DateTime.now().difference(dt).inMinutes;
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
  }

  void _onStatusFilterChanged(String status) {
    setState(() => _selectedStatusFilter = status);
  }

  void _onSendQuote(_JobRequest job) {
    final l = LocalizationService.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuoteBottomSheetWidget(
        job: job,
        onQuoteSubmitted: (price, eta, paymentMethods) async {
          Navigator.pop(ctx);
          try {
            await SupabaseService.instance.sendQuote(
              requestId: job.id,
              price: price,
              etaMinutes: eta,
              paymentMethods: paymentMethods,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Quote of \$$price sent! ETA: $eta min',
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
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (_) {
            if (mounted) {
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
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.signUpLoginScreen,
        (r) => false,
      );
    }
  }

  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _signOut,
          tooltip: l.t('sign_out'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('job_requests'),
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              l.t('provider_dashboard'),
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: AppTheme.onSurface,
                onPressed: () {},
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            color: AppTheme.primary,
            tooltip: l.t('my_profile'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.providerProfileScreen),
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            color: AppTheme.primary,
            tooltip: l.t('my_services_pricing'),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.providerServicesScreen),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.serviceRequestScreen,
                (r) => false,
              ),
              icon: const Icon(Icons.directions_car_outlined, size: 15),
              label: Text(
                'Driver View',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isTablet ? _buildTabletLayout(l) : _buildPhoneLayout(l),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l.t('select_job_detail'),
                style: GoogleFonts.manrope(fontSize: 13),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.send_rounded, size: 18),
        label: Text(
          l.t('send_quote'),
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(LocalizationService l) {
    return Column(
      children: [
        ProviderStatsHeaderWidget(jobs: _jobs),
        JobFilterBarWidget(
          selectedFilter: _selectedFilter,
          selectedStatusFilter: _selectedStatusFilter,
          onFilterChanged: _onFilterChanged,
          onStatusFilterChanged: _onStatusFilterChanged,
        ),
        Expanded(
          child: _isLoading
              ? const JobListSkeletonWidget()
              : _filteredJobs.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.work_off_outlined,
                  title: l.t('no_job_requests'),
                  description: l.t('new_jobs_info'),
                  ctaLabel: l.t('update_services'),
                  onCta: () => Navigator.pushNamed(
                    context,
                    AppRoutes.providerServicesScreen,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadJobs,
                  color: AppTheme.primary,
                  child: _buildJobList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(LocalizationService l) {
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: Column(
            children: [
              JobFilterBarWidget(
                selectedFilter: _selectedFilter,
                selectedStatusFilter: _selectedStatusFilter,
                onFilterChanged: _onFilterChanged,
                onStatusFilterChanged: _onStatusFilterChanged,
              ),
              Expanded(
                child: _isLoading
                    ? const JobListSkeletonWidget()
                    : _filteredJobs.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.work_off_outlined,
                        title: l.t('no_job_requests'),
                        description: l.t('new_jobs'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobs,
                        color: AppTheme.primary,
                        child: _buildJobList(),
                      ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: AppTheme.outlineVariant),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ProviderStatsHeaderWidget(jobs: _jobs),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.touch_app_outlined,
                      title: l.t('select_job_detail'),
                      description:
                          'Tap any job request on the left to see full details and send a quote.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filteredJobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = _filteredJobs[index];
        final delay = Duration(milliseconds: 50 * index);
        return _AnimatedJobCard(
          key: ValueKey(job.id),
          job: job,
          delay: delay,
          listController: _listController,
          onSendQuote: () => _onSendQuote(job),
          onStatusChanged: _loadJobs,
        );
      },
    );
  }
}

class _AnimatedJobCard extends StatefulWidget {
  final _JobRequest job;
  final Duration delay;
  final AnimationController listController;
  final VoidCallback onSendQuote;
  final VoidCallback? onStatusChanged;

  const _AnimatedJobCard({
    super.key,
    required this.job,
    required this.delay,
    required this.listController,
    required this.onSendQuote,
    this.onStatusChanged,
  });

  @override
  State<_AnimatedJobCard> createState() => _AnimatedJobCardState();
}

class _AnimatedJobCardState extends State<_AnimatedJobCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        );
      },
      child: Dismissible(
        key: ValueKey('dismiss-${widget.job.id}'),
        direction: widget.job.status == 'completed'
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.successContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.archive_outlined, color: AppTheme.success),
        ),
        child: JobRequestCardWidget(
          job: JobRequest(
            id: widget.job.id,
            serviceType: widget.job.serviceType,
            serviceIcon: widget.job.serviceIcon,
            urgency: widget.job.urgency,
            driverName: widget.job.driverName,
            driverImageUrl: widget.job.driverImageUrl,
            driverImageSemanticLabel: widget.job.driverImageSemanticLabel,
            address: widget.job.address,
            distanceMiles: widget.job.distanceMiles,
            description: widget.job.description,
            estimatedValue: widget.job.estimatedValue,
            status: widget.job.status,
            quoteSent: widget.job.quoteSent,
            postedMinutesAgo: widget.job.postedMinutesAgo,
          ),
          onSendQuote: widget.onSendQuote,
          onStatusChanged: widget.onStatusChanged,
        ),
      ),
    );
  }
}

class _JobRequest {
  final String id;
  final String serviceType;
  final String serviceIcon;
  final String driverName;
  final String driverPhone;
  final String address;
  final double distanceMiles;
  final String description;
  final int postedMinutesAgo;
  final String urgency;
  final String status;
  final double estimatedValue;
  final bool quoteSent;
  final String driverImageUrl;
  final String driverImageSemanticLabel;

  _JobRequest({
    required this.id,
    required this.serviceType,
    required this.serviceIcon,
    required this.driverName,
    required this.driverPhone,
    required this.address,
    required this.distanceMiles,
    required this.description,
    required this.postedMinutesAgo,
    required this.urgency,
    required this.status,
    required this.estimatedValue,
    required this.quoteSent,
    required this.driverImageUrl,
    required this.driverImageSemanticLabel,
  });
}
