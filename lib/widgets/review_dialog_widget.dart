import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

class ReviewDialogWidget extends StatefulWidget {
  final String bookingId;
  final VoidCallback onSubmitted;

  const ReviewDialogWidget({
    super.key,
    required this.bookingId,
    required this.onSubmitted,
  });

  static void show(BuildContext context, String bookingId, VoidCallback onSubmitted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewDialogWidget(bookingId: bookingId, onSubmitted: onSubmitted),
    );
  }

  @override
  State<ReviewDialogWidget> createState() => _ReviewDialogWidgetState();
}

class _ReviewDialogWidgetState extends State<ReviewDialogWidget> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.instance.submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        review: _reviewController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
      }
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)),
          ),
          Text(
            'Rate Your Experience',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = starIndex),
                icon: Icon(
                  Icons.star_rounded,
                  size: 40,
                  color: starIndex <= _rating ? Colors.amber : AppTheme.muted.withAlpha(80),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell us about the service…',
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(l.t('success'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
