import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';

import '../../widgets/review_dialog_widget.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await SupabaseService.instance.getJobHistory();
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppTheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.t('service_history'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? _buildEmptyState(l)
          : _buildHistoryList(l),
    );
  }

  Widget _buildEmptyState(LocalizationService l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppTheme.muted.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('none'),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(LocalizationService l) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final Map<String, dynamic> item = _history[index];
        final Map<String, dynamic> job =
            item['job_request'] as Map<String, dynamic>? ?? {};
        final String? currentUserId = SupabaseService.instance.currentUser?.id;
        final bool isProvider = currentUserId == item['provider_id'];

        String otherParty = 'User';
        if (isProvider) {
          otherParty =
              (item['customer'] as Map<String, dynamic>?)?['full_name'] ??
              'Customer';
        } else {
          otherParty =
              (item['provider'] as Map<String, dynamic>?)?['business_name'] ??
              'Provider';
        }

        final bool showRatingButton =
            (isProvider == false) && (item['customer_rating'] == null);
        final bool showStars =
            (isProvider == false) && (item['customer_rating'] != null);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    job['service_type'] ?? 'Service',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '\$${(item['final_price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'With $otherParty',
                style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(item['completed_at'] as String?),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                  const Spacer(),
                  if (showRatingButton)
                    TextButton(
                      onPressed: () => _showReviewDialog(item['id'] as String),
                      child: Text(l.t('rating')),
                    ),
                  if (showStars)
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: i < (item['customer_rating'] as int)
                              ? Colors.amber
                              : AppTheme.muted.withAlpha(100),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '--';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  void _showReviewDialog(String bookingId) {
    ReviewDialogWidget.show(context, bookingId, _loadHistory);
  }
}
