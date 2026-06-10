import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roadrescue_shared/models/support_ticket.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/theme/app_theme.dart';
import 'package:roadrescue_shared/widgets/create_support_ticket_dialog.dart';
import 'package:roadrescue_shared/widgets/support_ticket_detail_widget.dart';
import 'package:roadrescue_shared/widgets/support_ticket_list_widget.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  SupportTicket? _selectedTicket;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final tickets = await SupabaseService.instance.getSupportTickets(userId: userId);
      if (mounted) setState(() => _tickets = tickets);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showCreateDialog() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return;
    final ticket = await CreateSupportTicketDialog.show(
      context,
      userId: userId,
      userRole: 'customer',
    );
    if (ticket != null) _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    final ts = ThemeService.instance;

    return PopScope(
      canPop: _selectedTicket == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTicket != null) {
          setState(() => _selectedTicket = null);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _selectedTicket != null
            ? _buildDetailView(ts, l)
            : _buildListView(ts, l),
      ),
    );
  }

  Widget _buildListView(ThemeService ts, LocalizationService l) {
    final screenBg = ts.supportScreenBgColor.withAlpha((255 * ts.supportScreenBgOpacity).round());
    return Scaffold(
      key: const ValueKey('support_list'),
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        title: Text(
          l.t('support_tickets'),
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: SupportTicketListWidget(
                tickets: _tickets,
                onTap: (ticket) => setState(() => _selectedTicket = ticket),
                bottomPadding: 70,
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: _showCreateDialog,
          backgroundColor: ts.supportFabBgColor,
          child: Icon(Icons.add, color: ts.supportFabIconColor),
        ),
      ),
    );
  }

  Widget _buildDetailView(ThemeService ts, LocalizationService l) {
    final userId = SupabaseService.instance.currentUser?.id ?? '';
    final screenBg = ts.supportChatBgColor;
    return Scaffold(
      key: const ValueKey('support_detail'),
      backgroundColor: screenBg,
      appBar: AppBar(
        backgroundColor: screenBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withAlpha(20),
        leading: BackButton(onPressed: () => setState(() => _selectedTicket = null)),
        title: Text(
          l.t('support'),
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
        ),
      ),
      body: SupportTicketDetailWidget(
        ticketId: _selectedTicket!.id,
        currentUserId: userId,
        currentUserRole: 'customer',
        initialTicket: _selectedTicket,
        bottomPadding: 70,
      ),
    );
  }
}
