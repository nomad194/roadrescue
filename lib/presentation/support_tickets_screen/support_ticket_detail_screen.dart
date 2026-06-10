import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/models/support_ticket.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/widgets/support_ticket_detail_widget.dart';

class SupportTicketDetailScreen extends StatelessWidget {
  final SupportTicket ticket;

  const SupportTicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final userId = SupabaseService.instance.currentUser?.id ?? '';
    final ts = ThemeService.instance;
    final screenBg = ts.supportChatBgColor;
    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        title: Text(
          l.t('support'),
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: SupportTicketDetailWidget(
        ticketId: ticket.id,
        currentUserId: userId,
        currentUserRole: 'customer',
        initialTicket: ticket,
      ),
    );
  }
}
