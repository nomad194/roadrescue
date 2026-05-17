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
  List<dynamic> _faqs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final settings = await SupabaseService.instance.getAppSettings([
      'terms_of_service',
      'faq_content',
    ]);
    if (mounted) {
      setState(() {
        _tosContent = settings['terms_of_service'] ?? 'No terms available.';
        try {
          final faqJson = settings['faq_content'];
          if (faqJson != null) {
            final decoded = json.decode(faqJson);
            if (decoded is List) {
              _faqs = decoded;
            } else {
              _faqs = [];
            }
          } else {
            // Default FAQs if none in DB
            _faqs = [
              {
                'q': 'How quickly can I get help?',
                'a': 'Most providers arrive within 15–45 minutes.',
              },
              {'q': 'How do I pay?', 'a': 'You can pay via card or cash.'},
            ];
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
          tabs: [
            Tab(text: l.t('faq')),
            Tab(text: l.t('terms_of_service')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildFaqTab(l), _buildTosTab()],
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
        return ExpansionTile(
          title: Text(
            faq['q'] ?? '',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                faq['a'] ?? '',
                style: GoogleFonts.manrope(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        _tosContent,
        style: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.6,
          color: AppTheme.onSurface,
        ),
      ),
    );
  }
}
