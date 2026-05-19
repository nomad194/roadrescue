import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/localization_service.dart';

class FaqTosScreen extends StatefulWidget {
  const FaqTosScreen({super.key});

  @override
  State<FaqTosScreen> createState() => _FaqTosScreenState();
}

class _FaqTosScreenState extends State<FaqTosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _tosContent = '';
  String _privacyContent = '';
  List<dynamic> _faqs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final settings = await SupabaseService.instance.getAppSettings([
      'terms_of_service',
      'privacy_policy',
      'faq_content',
    ]);
    if (mounted) {
      setState(() {
        final l = LocalizationService.instance;
        
        // Handle ToS
        final tosRaw = settings['terms_of_service'] ?? '';
        try {
          final decoded = json.decode(tosRaw);
          _tosContent = l.translateContent(Map<String, dynamic>.from(decoded), fallbackText: 'No terms available.');
        } catch (_) {
          _tosContent = tosRaw.isNotEmpty ? tosRaw : 'No terms available.';
        }

        // Handle Privacy
        final privRaw = settings['privacy_policy'] ?? '';
        try {
          final decoded = json.decode(privRaw);
          _privacyContent = l.translateContent(Map<String, dynamic>.from(decoded), fallbackText: 'No privacy policy available.');
        } catch (_) {
          _privacyContent = privRaw.isNotEmpty ? privRaw : 'No privacy policy available.';
        }

        // Handle FAQs
        try {
          final faqJson = settings['faq_content'];
          if (faqJson != null) {
            _faqs = json.decode(faqJson) as List;
          } else {
            _faqs = [];
          }
        } catch (_) {
          _faqs = [];
        }
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
          'Support & Legal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.primary,
          isScrollable: true,
          tabs: [
            Tab(text: l.t('faq')),
            Tab(text: l.t('terms_of_service')),
            Tab(text: l.t('privacy_policy')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFaqTab(l),
                _buildTosTab(_tosContent),
                _buildTosTab(_privacyContent),
              ],
            ),
    );
  }

  Widget _buildFaqTab(LocalizationService l) {
    if (_faqs.isEmpty) {
      return Center(
        child: Text(
          'No FAQs found',
          style: GoogleFonts.manrope(color: AppTheme.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faqs.length,
      itemBuilder: (context, index) {
        final faq = _faqs[index];
        final q = l.translateContent(Map<String, dynamic>.from(faq['translations_q'] ?? {}), fallbackText: faq['q'] ?? '');
        final a = l.translateContent(Map<String, dynamic>.from(faq['translations_a'] ?? {}), fallbackText: faq['a'] ?? '');
        
        return ExpansionTile(
          title: Text(
            q,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                a,
                style: GoogleFonts.manrope(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTosTab(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.6,
          color: AppTheme.onSurface,
        ),
      ),
    );
  }
}
