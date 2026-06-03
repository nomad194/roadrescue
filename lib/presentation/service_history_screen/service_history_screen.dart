import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/localization_service.dart';

import 'package:roadrescue_shared/widgets/review_dialog_widget.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
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
          otherName = customerData?['full_name'] as String? ?? 'Customer';
          otherAvatarUrl = customerData?['avatar_url'] as String?;
        } else {
          final business = providerData?['business_name'] as String?;
          final providerName = providerData?['full_name'] as String? ?? 'Provider';
          otherName = business?.isNotEmpty == true ? business! : providerName;
          otherSubtitle = business?.isNotEmpty == true ? providerName : null;
          otherAvatarUrl = providerData?['avatar_url'] as String?;
        }

        final String serviceType = item['service_type'] as String? ?? 'Service';
        final double? price = (item['quoted_price'] as num?)?.toDouble();
        final bool showRatingButton = !isProvider && item['customer_rating'] == null;
        final bool showStars = !isProvider && item['customer_rating'] != null;
        final String? completedAt = item['updated_at'] as String? ?? item['created_at'] as String?;

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
                      ),
                    ),
                  ),
                  Text(
                    price != null ? '\$${price.toStringAsFixed(2)}' : '--',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: price != null ? AppTheme.primary : AppTheme.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Other party row with avatar
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryContainer,
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
                              color: AppTheme.primary,
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
                          color: AppTheme.onSurface,
                        ),
                      ),
                      if (otherSubtitle != null)
                        Text(
                          otherSubtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(completedAt),
                        style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
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
                        icon: const Icon(Icons.star_border_rounded, size: 16),
                        label: Text(l.t('rating')),
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
                              : AppTheme.muted.withAlpha(100),
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
                    color: AppTheme.onSurfaceVariant,
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
            color: AppTheme.muted,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
