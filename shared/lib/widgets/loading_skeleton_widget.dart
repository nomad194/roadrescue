import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnimation = Tween<double>(
      begin: -0.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceVariant,
                AppTheme.surfaceVariant.withAlpha(128),
                AppTheme.surfaceVariant,
              ],
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

class JobListSkeletonWidget extends StatelessWidget {
  const JobListSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
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
                children: [
                  const LoadingSkeletonWidget(
                    width: 80,
                    height: 22,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 8),
                  const LoadingSkeletonWidget(
                    width: 60,
                    height: 22,
                    borderRadius: 6,
                  ),
                  const Spacer(),
                  const LoadingSkeletonWidget(
                    width: 50,
                    height: 18,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const LoadingSkeletonWidget(
                width: double.infinity,
                height: 14,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              const LoadingSkeletonWidget(
                width: 200,
                height: 14,
                borderRadius: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  LoadingSkeletonWidget(width: 80, height: 12, borderRadius: 4),
                  SizedBox(width: 16),
                  LoadingSkeletonWidget(width: 80, height: 12, borderRadius: 4),
                  Spacer(),
                  LoadingSkeletonWidget(width: 90, height: 36, borderRadius: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
