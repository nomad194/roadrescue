import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum JobStatus {
  pending,
  quotesSent,
  accepted,
  enRoute,
  inProgress,
  completed,
  cancelled,
}

extension JobStatusExtension on JobStatus {
  String get label {
    switch (this) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.quotesSent:
        return 'Quotes Sent';
      case JobStatus.accepted:
        return 'Accepted';
      case JobStatus.enRoute:
        return 'En Route';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case JobStatus.pending:
        return AppTheme.warning;
      case JobStatus.quotesSent:
        return AppTheme.primary;
      case JobStatus.accepted:
        return AppTheme.primaryLight;
      case JobStatus.enRoute:
        return AppTheme.secondary;
      case JobStatus.inProgress:
        return AppTheme.success;
      case JobStatus.completed:
        return AppTheme.success;
      case JobStatus.cancelled:
        return AppTheme.error;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case JobStatus.pending:
        return AppTheme.warningContainer;
      case JobStatus.quotesSent:
        return AppTheme.primaryContainer;
      case JobStatus.accepted:
        return AppTheme.primaryContainer;
      case JobStatus.enRoute:
        return AppTheme.secondaryContainer;
      case JobStatus.inProgress:
        return AppTheme.successContainer;
      case JobStatus.completed:
        return AppTheme.successContainer;
      case JobStatus.cancelled:
        return AppTheme.errorContainer;
    }
  }
}

class StatusBadgeWidget extends StatelessWidget {
  final JobStatus status;
  final bool compact;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.manrope(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: status.color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
