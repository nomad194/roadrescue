import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';

import 'package:roadrescue_shared/widgets/review_dialog_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    _subscription = Supabase.instance.client
        .channel('history_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (payload) {
            if (mounted) _loadHistory();
          },
        )
        .subscribe();
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
    final ts = ThemeService.instance;
    final screenBg = ts.userScreenBgColor.withAlpha((255 * ts.userScreenBgOpacity).round());
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        title: Text(
          l.t('service_history'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: AppTheme.primary,
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _history.isEmpty
                ? _buildEmptyState(l)
                : _buildHistoryList(l),
      ),
    );
  }

  Widget _buildEmptyState(LocalizationService l) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 64,
                  color: Colors.white.withAlpha(180),
                ),
                const SizedBox(height: 16),
                Text(
                  l.t('none'),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(LocalizationService l) {
    final String? currentUserId = SupabaseService.instance.currentUser?.id;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final Map<String, dynamic> item = _history[index];
        final bool isProvider = currentUserId == item['provider_id'];

        final Map<String, dynamic>? customerData = item['customer'] as Map<String, dynamic>?;
        final Map<String, dynamic>? providerData = item['provider'] as Map<String, dynamic>?;

        // Other party info
        String otherName;
        String? otherSubtitle;
        String? otherAvatarUrl;
        if (isProvider) {
          otherName = customerData?['full_name'] as String? ?? l.t('customer');
          otherAvatarUrl = customerData?['avatar_url'] as String?;
        } else {
          final business = providerData?['business_name'] as String?;
          final providerName = providerData?['full_name'] as String? ?? l.t('provider');
          otherName = business?.isNotEmpty == true ? business! : providerName;
          otherSubtitle = business?.isNotEmpty == true ? providerName : null;
          otherAvatarUrl = providerData?['avatar_url'] as String?;
        }

        final String serviceType = item['service_type'] as String? ?? '';
        final double? price = (item['quoted_price'] as num?)?.toDouble();
        final bool showRatingButton = !isProvider && item['customer_rating'] == null;
        final bool showStars = !isProvider && item['customer_rating'] != null;
        final String? completedAt = item['updated_at'] as String? ?? item['created_at'] as String?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: service type + price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      serviceType,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    price != null ? '\$${price.toStringAsFixed(2)}' : '--',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: price != null ? AppTheme.serviceRequestAccent : Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.white.withAlpha(40)),
              const SizedBox(height: 12),
              // Other party row with avatar
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withAlpha(40),
                    backgroundImage: otherAvatarUrl != null && otherAvatarUrl.isNotEmpty
                        ? NetworkImage(otherAvatarUrl) as ImageProvider
                        : null,
                    onBackgroundImageError: otherAvatarUrl != null && otherAvatarUrl.isNotEmpty
                        ? (_, _) {}
                        : null,
                    child: otherAvatarUrl == null || otherAvatarUrl.isEmpty
                        ? Text(
                            otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.serviceRequestAccent,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherName,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (otherSubtitle != null)
                        Text(
                          otherSubtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: Colors.white.withAlpha(180),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withAlpha(180)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(completedAt),
                        style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withAlpha(180)),
                      ),
                    ],
                  ),
                ],
              ),
              // Stars / rate button
              if (showRatingButton || showStars) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (showRatingButton)
                      TextButton.icon(
                        onPressed: () => _showReviewDialog(item['id'] as String),
                        icon: Icon(Icons.star_border_rounded, size: 16, color: Colors.white.withAlpha(180)),
                        label: Text(l.t('rating'), style: TextStyle(color: Colors.white.withAlpha(180))),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (showStars)
                      Row(
                        children: List.generate(5, (i) => Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: i < (item['customer_rating'] as int)
                              ? Colors.amber
                              : Colors.white.withAlpha(80),
                        )),
                      ),
                  ],
                ),
              ],
              // Review comment
              if (item['customer_review'] != null && item['customer_review'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${item['customer_review']}"',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.white.withAlpha(180),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              // Visibility toggle
              if (!isProvider && item['reviews'] != null && (item['reviews'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    _buildVisibilityToggle((item['reviews'] as List).first),
                  ],
                ),
              ],
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

  Widget _buildVisibilityToggle(Map<String, dynamic> review) {
    final isPublic = review['is_public'] as bool? ?? true;
    final reviewId = review['id'] as String? ?? '';
    
    return InkWell(
      onTap: () async {
        try {
          await SupabaseService.instance.toggleReviewVisibility(
            reviewId: reviewId,
            isPublic: !isPublic,
          );
          _loadHistory();
        } catch (e) {
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 14,
            color: Colors.white.withAlpha(180),
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? LocalizationService.instance.t('public') : LocalizationService.instance.t('private'),
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}
