import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';

class ProviderReviewsScreen extends StatefulWidget {
  final String? providerId;
  
  const ProviderReviewsScreen({super.key, this.providerId});

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  int _totalReviews = 0;
  final _responseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final providerId = widget.providerId ?? SupabaseService.instance.currentUser?.id;
    if (providerId == null) return;

    setState(() => _isLoading = true);
    try {
      final rating = await SupabaseService.instance.getProviderRating(providerId);
      final reviews = await SupabaseService.instance.getProviderReviews(providerId);
      
      if (mounted) {
        setState(() {
          _averageRating = rating['average_rating'];
          _totalReviews = rating['total_reviews'];
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResponseDialog(String reviewId) async {
    _responseController.clear();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Respond to Review',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: _responseController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Write your response...',
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.instance.addProviderResponse(
                  reviewId: reviewId,
                  response: _responseController.text.trim(),
                );
                Navigator.pop(ctx);
                _loadReviews();
              } catch (e) {
                debugPrint('Error adding response: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final currentUserId = SupabaseService.instance.currentUser?.id;
    final isOwnProfile = widget.providerId == null || widget.providerId == currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reviews & Ratings',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Rating Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: GoogleFonts.manrope(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 24,
                              color: i < _averageRating.round()
                                  ? Colors.amber
                                  : AppTheme.muted.withAlpha(80),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalReviews reviews',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Reviews List
                  if (_reviews.isEmpty)
                    Center(
                      child: Text(
                        'No reviews yet',
                        style: GoogleFonts.manrope(
                          color: AppTheme.muted,
                        ),
                      ),
                    )
                  else
                    ..._reviews.map((review) {
                      final rating = review['rating'] as int? ?? 0;
                      final comment = review['comment'] as String? ?? '';
                      final reviewerName = (review['reviewer'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Anonymous';
                      final providerResponse = review['provider_response'] as String?;
                      final isPublic = review['is_public'] as bool? ?? true;
                      final reviewId = review['id'] as String? ?? '';
                      final canRespond = isOwnProfile && providerResponse == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: i < rating ? Colors.amber : AppTheme.muted.withAlpha(80),
                                  ),
                                ),
                                const Spacer(),
                                if (!isPublic)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Private',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"$comment"',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '- $reviewerName',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                            ),
                            // Provider Response
                            if (providerResponse != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Provider Response:',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      providerResponse,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Respond Button (only for provider's own reviews)
                            if (canRespond && isPublic) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showResponseDialog(reviewId),
                                  child: Text(
                                    'Respond',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
