import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/multilingual_tabs_widget.dart';

class AdminAppConfigWidget extends StatefulWidget {
  const AdminAppConfigWidget({super.key});

  @override
  State<AdminAppConfigWidget> createState() => _AdminAppConfigWidgetState();
}

class _AdminAppConfigWidgetState extends State<AdminAppConfigWidget>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;
  int _selectedInnerTab = 0;

  final List<Map<String, String>> _innerTabs = [
    {'label': 'General', 'icon': 'settings'},
    {'label': 'API Keys', 'icon': 'key'},
    {'label': 'Appearance', 'icon': 'palette'},
    {'label': 'Social', 'icon': 'share'},
    {'label': 'Content', 'icon': 'article'},
    {'label': 'Languages', 'icon': 'language'},
    {'label': 'Documents', 'icon': 'folder'},
  ];

  // General
  final _appNameController = TextEditingController(text: 'RoadRescue');
  final _appTaglineController = TextEditingController(
    text: 'Roadside Assistance On Demand',
  );
  final _supportEmailController = TextEditingController(
    text: 'support@roadrescue.com',
  );
  final _supportPhoneController = TextEditingController(
    text: '+1 (800) 555-0100',
  );
  String _distanceUnit = 'mi';

  // API Keys
  final _googleMapsKeyController = TextEditingController();
  final _stripeKeyController = TextEditingController();
  final _twilioSidController = TextEditingController();
  final _twilioTokenController = TextEditingController();
  final _firebaseKeyController = TextEditingController();
  bool _showApiKeys = false;

  // Appearance
  Color _primaryColor = AppTheme.primary;
  Color _secondaryColor = AppTheme.secondary;
  Color _currentPlanColor = const Color(0xFF1A56DB); // Default Blue
  final _logoUrlController = TextEditingController(
    text:
        'https://img.rocket.new/generatedImages/rocket_gen_img_194e798b6-1763300798761.png',
  );
  bool _sliderEnabled = true;
  final List<Map<String, String>> _sliderImages = [
    {
      'url':
          'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800&h=300&fit=crop',
      'caption': 'Fast Roadside Assistance',
    },
    {
      'url':
          'https://img.rocket.new/generatedImages/rocket_gen_img_13bc19e2c-1771518184060.png',
      'caption': 'Professional Providers Near You',
    },
  ];

  // Social Links
  final _facebookController = TextEditingController(
    text: 'https://facebook.com/roadrescue',
  );
  final _instagramController = TextEditingController(
    text: 'https://instagram.com/roadrescue',
  );
  final _twitterController = TextEditingController(
    text: 'https://twitter.com/roadrescue',
  );
  final _linkedinController = TextEditingController(text: '');
  final _youtubeController = TextEditingController(text: '');

  // FAQ — each item now has multilingual translations
  final List<Map<String, dynamic>> _faqs = [
    {
      'translations_q': <String, String>{
        'en': 'How quickly can I get help?',
        'es': '¿Qué tan rápido puedo obtener ayuda?',
        'fr': 'À quelle vitesse puis-je obtener de l\'aide?',
        'pt': 'Com que rapidez posso obter ajuda?',
        'de': 'Wie schnell kann ich Hilfe bekommen?',
        'ar': 'كم من الوقت يستغرق الحصول على المساعدة؟',
      },
      'translations_a': <String, String>{
        'en':
            'Most providers arrive within 15–45 minutes depending on your location and service type.',
        'es':
            'La mayoría de los proveedores llegan en 15 a 45 minutos según tu ubicación y tipo de servicio.',
        'fr':
            'La plupart des prestataires arrivent en 15 à 45 minutes selon votre emplacement.',
        'pt':
            'A maioria dos prestadores chega em 15 a 45 minutos dependendo da sua localização.',
        'de':
            'Die meisten Anbieter kommen innerhalb von 15–45 Minuten, je nach Standort.',
        'ar':
            'يصل معظم مزودي الخدمة خلال 15 إلى 45 دقيقة حسب موقعك ونوع الخدمة.',
      },
    },
    {
      'translations_q': <String, String>{
        'en': 'How do I pay for services?',
        'es': '¿Cómo pago los servicios?',
        'fr': 'Comment puis-je payer les services?',
        'pt': 'Como pago pelos serviços?',
        'de': 'Wie bezahle ich für Dienstleistungen?',
        'ar': 'كيف أدفع مقابل الخدمات؟',
      },
      'translations_a': <String, String>{
        'en':
            'You can pay via credit card, debit card, or cash depending on the provider.',
        'es':
            'Puedes pagar con tarjeta de crédito, débito o efectivo según el proveedor.',
        'fr':
            'Vous pouvez payer par carte de crédit, débit ou espèces selon le prestataire.',
        'pt':
            'Você puede pagar com cartão de crédito, débito ou dinheiro dependendo do prestador.',
        'de': 'Sie können per Kreditkarte, Debitkarte oder Bargeld bezahlen.',
        'ar': 'يمكنك الدفع ببطاقة الائتمان أو الخصم أو النقد حسب المزود.',
      },
    },
    {
      'translations_q': <String, String>{
        'en': 'Can I track my provider?',
        'es': '¿Puedo rastrear a mi proveedor?',
        'fr': 'Puis-je suivre mon prestataire?',
        'pt': 'Posso rastrear meu prestador?',
        'de': 'Kann ich meinen Anbieter verfolgen?',
        'ar': 'هل يمكنني تتبع مزود الخدمة؟',
      },
      'translations_a': <String, String>{
        'en':
            'Yes! Once a provider accepts your request, you can track their location in real-time.',
        'es':
            '¡Sí! Una vez que un proveedor acepta tu solicitud, puedes rastrear su ubicación en tiempo real.',
        'fr':
            'Oui! Une fois qu\'un prestataire accepte votre demande, vous pouvez suivre sa position en tiempo réel.',
        'pt':
            'Sim! Assim que um prestador aceitar sua solicitação, você pode rastrear sua localização em tempo real.',
        'de':
            'Ja! Sobald ein Anbieter Ihre Anfrage annimmt, können Sie seinen Standort in Echtzeit verfolgen.',
        'ar': 'نعم! بمجرد قبول المزود لطلبك، يمكنك تتبع موقعه في الوقت الفعلي.',
      },
    },
  ];

  // Terms & Conditions — multilingual
  Map<String, String> _termsTranslations = {
    'en':
        'Welcome to RoadRescue. By using our service, you agree to the following terms and conditions...\n\n1. Service Agreement\nRoadRescue connects customers with independent roadside assistance providers...\n\n2. Payment Terms\nAll payments are processed securely through our platform...\n\n3. Liability\nRoadRescue acts as a marketplace and is not liable for...',
    'es':
        'Bienvenido a RoadRescue. Al usar nuestro servicio, acepta los siguientes términos y condiciones...\n\n1. Acuerdo de Servicio\nRoadRescue conecta a los clientes con proveedores independientes de asistencia en carretera...',
    'fr':
        'Bienvenue sur RoadRescue. En utilisant notre service, vous acceptez les conditions suivantes...\n\n1. Accord de Service\nRoadRescue met en relation les clients avec des prestataires indépendants...',
    'pt':
        'Bem-vindo ao RoadRescue. Ao usar nosso serviço, você concorda com os seguintes termos...\n\n1. Acordo de Serviço\nRoadRescue conecta clientes com prestadores independentes de assistência...',
    'de':
        'Willkommen bei RoadRescue. Durch die Nutzung unseres Dienstes stimmen Sie den folgenden Bedingungen zu...\n\n1. Dienstleistungsvertrag\nRoadRescue verbindet Kunden mit unabhängigen Pannenhilfe-Anbietern...',
    'ar':
        'مرحباً بك في رود ريسكيو. باستخدام خدمتنا، فإنك توافق على الشروط والأحكام التالية...\n\n1. اتفاقية الخدمة\nيربط رود ريسكيو العملاء بمزودي خدمة المساعدة على الطريق المستقلين...',
  };

  // Privacy Policy — multilingual
  Map<String, String> _privacyTranslations = {
    'en':
        'Privacy Policy\n\nLast updated: January 2026\n\nRoadRescue ("we", "us", or "our") is committed to protecting your privacy...\n\n1. Information We Collect\nWe collect information you provide directly to us...\n\n2. How We Use Your Information\nWe use the information we collect to provide, maintain, and improve our services...',
    'es':
        'Política de Privacidad\n\nÚltima actualización: Enero 2026\n\nRoadRescue está comprometido con la protección de su privacidad...\n\n1. Información que Recopilamos\nRecopilamos la información que nos proporciona directamente...',
    'fr':
        'Politique de Confidentialité\n\nDernière mise à jour: Janvier 2026\n\nRoadRescue s\'engage à protéger votre vie privée...\n\n1. Informations que Nous Collectons\nNous collectons les informations que vous nous fournissez directamente...',
    'pt':
        'Política de Privacidade\n\nÚltima atualização: Janeiro 2026\n\nRoadRescue está comprometido em proteger sua privacidade...\n\n1. Informações que Coletamos\nColetamos informações que você nos fornece diretamente...',
    'de':
        'Datenschutzrichtlinie\n\nZuletzt aktualisiert: Januar 2026\n\nRoadRescue verpflichtet sich, Ihre Privatsphäre zu schützen...\n\n1. Informationen, die wir sammeln\nWir sammeln Informationen, die Sie uns direkt zur Verfügung stellen...',
    'ar':
        'سياسة الخصوصية\n\nآخر تحديث: يناير 2026\n\nيلتزم رود ريسكيو بحماية خصوصيتك...\n\n1. المعلومات التي نجمعها\nنجمع المعلومات التي تقدمها لنا مباشرة...',
  };

  // Languages
  final List<Map<String, dynamic>> _languages = [
    {'code': 'en', 'name': 'English', 'isDefault': true, 'active': true},
    {'code': 'es', 'name': 'Spanish', 'isDefault': false, 'active': true},
    {'code': 'fr', 'name': 'French', 'isDefault': false, 'active': false},
    {'code': 'pt', 'name': 'Portuguese', 'isDefault': false, 'active': false},
  ];

  // Required Documents
  final List<Map<String, dynamic>> _requiredDocs = [
    {
      'id': 1,
      'name': 'Driver\'s License',
      'required': true,
      'description': 'Valid government-issued driver\'s license',
    },
    {
      'id': 2,
      'name': 'Vehicle Registration',
      'required': true,
      'description': 'Current vehicle registration document',
    },
    {
      'id': 3,
      'name': 'Insurance Certificate',
      'required': true,
      'description': 'Valid liability insurance certificate',
    },
    {
      'id': 4,
      'name': 'Background Check',
      'required': true,
      'description': 'Recent background check clearance',
    },
    {
      'id': 5,
      'name': 'Profile Photo',
      'required': false,
      'description': 'Clear headshot photo for your profile',
    },
  ];

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: _innerTabs.length, vsync: this);
    _innerTabController.addListener(() {
      if (!_innerTabController.indexIsChanging) {
        setState(() => _selectedInnerTab = _innerTabController.index);
      }
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('setting_key, setting_value');
      
      final Map<String, String> settings = {
        for (final row in response as List)
          row['setting_key'] as String: row['setting_value'] as String
      };

      if (mounted) {
        setState(() {
          if (settings.containsKey('app_name')) _appNameController.text = settings['app_name']!;
          if (settings.containsKey('app_tagline')) _appTaglineController.text = settings['app_tagline']!;
          if (settings.containsKey('support_email')) _supportEmailController.text = settings['support_email']!;
          if (settings.containsKey('support_phone')) _supportPhoneController.text = settings['support_phone']!;
          if (settings.containsKey('distance_unit')) _distanceUnit = settings['distance_unit']!;
          
          if (settings.containsKey('google_maps_key')) _googleMapsKeyController.text = settings['google_maps_key']!;
          if (settings.containsKey('stripe_publishable_key')) _stripeKeyController.text = settings['stripe_publishable_key']!;
          
          if (settings.containsKey('logo_url')) _logoUrlController.text = settings['logo_url']!;
          
          if (settings.containsKey('current_plan_highlight_color')) {
            try {
              final hex = settings['current_plan_highlight_color']!.replaceFirst('#', '');
              _currentPlanColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}
          }

          if (settings.containsKey('faq_content')) {
             try {
               final List decoded = json.decode(settings['faq_content']!);
               _faqs.clear();
               _faqs.addAll(decoded.map((f) => Map<String, dynamic>.from(f)));
             } catch (_) {}
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    _appNameController.dispose();
    _appTaglineController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _googleMapsKeyController.dispose();
    _stripeKeyController.dispose();
    _twilioSidController.dispose();
    _twilioTokenController.dispose();
    _firebaseKeyController.dispose();
    _logoUrlController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  void _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('app_settings').upsert([
        {
          'setting_key': 'app_name',
          'setting_value': _appNameController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'app_tagline',
          'setting_value': _appTaglineController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'support_email',
          'setting_value': _supportEmailController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'support_phone',
          'setting_value': _supportPhoneController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'distance_unit',
          'setting_value': _distanceUnit,
          'setting_type': 'text',
        },
        {
          'setting_key': 'google_maps_key',
          'setting_value': _googleMapsKeyController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'stripe_publishable_key',
          'setting_value': _stripeKeyController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'logo_url',
          'setting_value': _logoUrlController.text.trim(),
          'setting_type': 'text',
        },
        {
          'setting_key': 'current_plan_highlight_color',
          'setting_value': '#${_currentPlanColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          'setting_type': 'text',
        },
        {
          'setting_key': 'terms_of_service',
          'setting_value': _termsTranslations['en'] ?? '',
          'setting_type': 'text',
        },
        {
          'setting_key': 'faq_content',
          'setting_value': json.encode(_faqs),
          'setting_type': 'json',
        },
      ], onConflict: 'setting_key');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configuration saved successfully!',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save config error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LocalizationService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('app_config_title'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  Text(
                    l.t('manage_settings'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : l.t('save_all'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_innerTabs.length, (index) {
              final isSelected = _selectedInnerTab == index;
              return GestureDetector(
                onTap: () {
                  _innerTabController.animateTo(index);
                  setState(() => _selectedInnerTab = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6, bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _innerTabs[index]['label']!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        _buildTabContent(l),
      ],
    );
  }

  Widget _buildTabContent(LocalizationService l) {
    switch (_selectedInnerTab) {
      case 0:
        return _buildGeneralTab(l);
      case 1:
        return _buildApiKeysTab(l);
      case 2:
        return _buildAppearanceTab(l);
      case 3:
        return _buildSocialTab(l);
      case 4:
        return _buildContentTab(l);
      case 5:
        return _buildLanguagesTab(l);
      case 6:
        return _buildDocumentsTab(l);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurface),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildGeneralTab(LocalizationService l) {
    return _buildSectionCard(
      title: l.t('general_settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('App Name', _appNameController),
          _buildTextField('App Tagline', _appTaglineController),
          _buildTextField('Support Email', _supportEmailController),
          _buildTextField('Support Phone', _supportPhoneController),
          const SizedBox(height: 8),
          Text(
            'Distance Unit',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildUnitToggle('mi', 'Miles (MI)'),
                _buildUnitToggle('km', 'Kilometers (KM)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(String value, String label) {
    final isSelected = _distanceUnit == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _distanceUnit = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeysTab(LocalizationService l) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.warning.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('api_keys_warning'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _showApiKeys,
                onChanged: (v) => setState(() => _showApiKeys = v),
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: l.t('integration_keys'),
          child: Column(
            children: [
              _buildTextField(
                'Google Maps API Key',
                _googleMapsKeyController,
                obscure: !_showApiKeys,
                hint: 'AIza...',
              ),
              _buildTextField(
                'Stripe Publishable Key',
                _stripeKeyController,
                obscure: !_showApiKeys,
                hint: 'pk_live_...',
              ),
              _buildTextField(
                'Twilio Account SID',
                _twilioSidController,
                obscure: !_showApiKeys,
                hint: 'AC...',
              ),
              _buildTextField(
                'Twilio Auth Token',
                _twilioTokenController,
                obscure: !_showApiKeys,
                hint: 'Auth token...',
              ),
              _buildTextField(
                'Firebase Server Key',
                _firebaseKeyController,
                obscure: !_showApiKeys,
                hint: 'AAAA...',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceTab(LocalizationService l) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'App Logo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                l.t('logo_image_url'),
                _logoUrlController,
                hint: 'https://...',
              ),
              if (_logoUrlController.text.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _logoUrlController.text,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: l.t('brand_colors'),
          child: Column(
            children: [
              _buildColorRow(
                'Primary Color',
                _primaryColor,
                (c) => setState(() => _primaryColor = c),
              ),
              const SizedBox(height: 10),
              _buildColorRow(
                'Secondary Color',
                _secondaryColor,
                (c) => setState(() => _secondaryColor = c),
              ),
              const SizedBox(height: 10),
              _buildColorRow(
                'Current Plan Highlight',
                _currentPlanColor,
                (c) => setState(() => _currentPlanColor = c),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Image Slider',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l.t('enable_slider'),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _sliderEnabled,
                    onChanged: (v) => setState(() => _sliderEnabled = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
              if (_sliderEnabled) ...[
                const SizedBox(height: 12),
                ...List.generate(_sliderImages.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _sliderImages[i]['url']!,
                            width: 60,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 40,
                              color: AppTheme.outline,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 20,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _sliderImages[i]['caption']!,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _sliderImages.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.errorContainer,
                            minimumSize: const Size(30, 30),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => _showAddSliderDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    l.t('add_slide'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorRow(
    String label,
    Color color,
    ValueChanged<Color> onChanged,
  ) {
    final colorOptions = [
      const Color(0xFF1A56DB),
      const Color(0xFF7C3AED),
      const Color(0xFF16A34A),
      const Color(0xFFDC2626),
      const Color(0xFFF97316),
      const Color(0xFF0891B2),
      const Color(0xFF9D174D),
      const Color(0xFF374151),
    ];
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.onSurface),
        ),
        const Spacer(),
        Wrap(
          spacing: 6,
          children: colorOptions.map((c) {
            final isSelected = color.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.onSurface : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAddSliderDialog() {
    final l = LocalizationService.instance;
    final urlController = TextEditingController();
    final captionController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l.t('add_slide'),
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(l.t('logo_image_url'), urlController, hint: 'https://...'),
            _buildTextField(
              'Caption',
              captionController,
              hint: 'Slide caption...',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.t('cancel'),
              style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.trim().isNotEmpty) {
                setState(
                  () => _sliderImages.add({
                    'url': urlController.text.trim(),
                    'caption': captionController.text.trim(),
                  }),
                );
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l.t('add_translation').split(' ')[0], // Just use "Add" logic
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTab(LocalizationService l) {
    return _buildSectionCard(
      title: 'Social Media Links',
      child: Column(
        children: [
          _buildSocialRow(
            Icons.facebook,
            'Facebook',
            _facebookController,
            const Color(0xFF1877F2),
          ),
          _buildSocialRow(
            Icons.camera_alt_outlined,
            'Instagram',
            _instagramController,
            const Color(0xFFE4405F),
          ),
          _buildSocialRow(
            Icons.alternate_email,
            'Twitter / X',
            _twitterController,
            const Color(0xFF1DA1F2),
          ),
          _buildSocialRow(
            Icons.work_outline,
            'LinkedIn',
            _linkedinController,
            const Color(0xFF0A66C2),
          ),
          _buildSocialRow(
            Icons.play_circle_outline,
            'YouTube',
            _youtubeController,
            const Color(0xFFFF0000),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRow(
    IconData icon,
    String label,
    TextEditingController controller,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://$label.com/...',
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: color, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the display text for an FAQ item in the current language
  String _faqText(Map<String, dynamic> faq, String key) {
    final l = LocalizationService.instance;
    final translations = faq[key] as Map<String, dynamic>? ?? {};
    return l.translateContent(translations, fallbackText: '');
  }

  Widget _buildContentTab(LocalizationService l) {
    return Column(
      children: [
        // FAQ Management with multilingual support
        _buildSectionCard(
          title: l.t('faq_management'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language info banner
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.translate,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Each FAQ supports translations per language. Click edit to manage translations.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(_faqs.length, (i) {
                final qText = _faqText(_faqs[i], 'translations_q');
                final aText = _faqText(_faqs[i], 'translations_a');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q: $qText',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A: $aText',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showFaqDialog(index: i),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => setState(() => _faqs.removeAt(i)),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppTheme.error,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.errorContainer,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => _showFaqDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Add FAQ',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Terms & Conditions — multilingual tabs
        _buildSectionCard(
          title: l.t('terms_of_service'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMultilingualInfoBanner(),
              const SizedBox(height: 10),
              MultilingualTabsWidget(
                initialTranslations: _termsTranslations,
                fieldLabel: l.t('terms_of_service'),
                hint: 'Enter terms of service text...',
                maxLines: 8,
                onChanged: (updated) =>
                    setState(() => _termsTranslations = updated),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Privacy Policy — multilingual tabs
        _buildSectionCard(
          title: l.t('privacy_policy'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMultilingualInfoBanner(),
              const SizedBox(height: 10),
              MultilingualTabsWidget(
                initialTranslations: _privacyTranslations,
                fieldLabel: l.t('privacy_policy'),
                hint: 'Enter privacy policy text...',
                maxLines: 8,
                onChanged: (updated) =>
                    setState(() => _privacyTranslations = updated),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultilingualInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.translate, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Switch tabs to enter translations for each language. Missing translations fall back to the default language.',
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog({int? index}) {
    final l = LocalizationService.instance;
    Map<String, String> qTranslations = index != null
        ? Map<String, String>.from(
            _faqs[index]['translations_q'] as Map<String, String>? ?? {},
          )
        : {};
    Map<String, String> aTranslations = index != null
        ? Map<String, String>.from(
            _faqs[index]['translations_a'] as Map<String, String>? ?? {},
          )
        : {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.translate, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                index == null ? 'Add FAQ' : 'Edit FAQ',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: qTranslations,
                    fieldLabel: 'Question',
                    hint: 'Enter question...',
                    maxLines: 2,
                    onChanged: (updated) => qTranslations = updated,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Answer',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MultilingualTabsWidget(
                    initialTranslations: aTranslations,
                    fieldLabel: 'Answer',
                    hint: 'Enter answer...',
                    maxLines: 3,
                    onChanged: (updated) => aTranslations = updated,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final hasContent = qTranslations.values.any(
                  (v) => v.isNotEmpty,
                );
                if (hasContent) {
                  setState(() {
                    if (index == null) {
                      _faqs.add({
                        'translations_q': qTranslations,
                        'translations_a': aTranslations,
                      });
                    } else {
                      _faqs[index] = {
                        'translations_q': qTranslations,
                        'translations_a': aTranslations,
                      };
                    }
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagesTab(LocalizationService l) {
    return _buildSectionCard(
      title: l.t('language_management'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'The default language is used as fallback when a translation is missing.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_languages.length, (i) {
            final lang = _languages[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: lang['isDefault']
                    ? Border.all(color: AppTheme.primary, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (lang['code'] as String).toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang['name'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        if (lang['isDefault'] as bool)
                          Text(
                            'Default Language',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: lang['active'] as bool,
                    onChanged: (v) =>
                        setState(() => _languages[i]['active'] = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                  if (!(lang['isDefault'] as bool))
                    IconButton(
                      onPressed: () {
                        setState(() {
                          for (var l in _languages) {
                            l['isDefault'] = false;
                          }
                          _languages[i]['isDefault'] = true;
                        });
                      },
                      icon: const Icon(
                        Icons.star_outline,
                        size: 18,
                        color: AppTheme.warning,
                      ),
                      tooltip: 'Set as default',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddLanguageDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              'Add Language',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLanguageDialog() {
    final l = LocalizationService.instance;
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Language',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppTheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              'Language Code',
              codeController,
              hint: 'e.g. de, ar, zh',
            ),
            _buildTextField(
              'Language Name',
              nameController,
              hint: 'e.g. German, Arabic',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.t('cancel'),
              style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeController.text.trim().isNotEmpty &&
                  nameController.text.trim().isNotEmpty) {
                setState(
                  () => _languages.add({
                    'code': codeController.text.trim().toLowerCase(),
                    'name': nameController.text.trim(),
                    'isDefault': false,
                    'active': true,
                  }),
                );
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l.t('add_translation').split(' ')[0],
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(LocalizationService l) {
    return _buildSectionCard(
      title: l.t('required_documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These documents will be required from providers during signup.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_requiredDocs.length, (i) {
            final doc = _requiredDocs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: doc['required']
                          ? AppTheme.primaryContainer
                          : AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: doc['required']
                          ? AppTheme.primary
                          : AppTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              doc['name'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (doc['required'] as bool)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Required',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          doc['description'] as String,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showDocumentDialog(index: i),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryContainer,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _requiredDocs.removeAt(i)),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.errorContainer,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => _showDocumentDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              'Add Document',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentDialog({int? index}) {
    final l = LocalizationService.instance;
    final nameController = TextEditingController(
      text: index != null ? _requiredDocs[index]['name'] as String : '',
    );
    final descController = TextEditingController(
      text: index != null ? _requiredDocs[index]['description'] as String : '',
    );
    bool isRequired = index != null
        ? _requiredDocs[index]['required'] as bool
        : true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            index == null ? 'Add Document' : 'Edit Document',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                'Document Name',
                nameController,
                hint: 'e.g. Driver\'s License',
              ),
              _buildTextField(
                'Description',
                descController,
                hint: 'Brief description...',
                maxLines: 2,
              ),
              Row(
                children: [
                  const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: isRequired,
                    onChanged: (v) => setDialogState(() => isRequired = v),
                    activeThumbColor: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.t('cancel'),
                style: GoogleFonts.manrope(color: AppTheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    if (index == null) {
                      _requiredDocs.add({
                        'id': _requiredDocs.length + 1,
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'required': isRequired,
                      });
                    } else {
                      _requiredDocs[index] = {
                        ..._requiredDocs[index],
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'required': isRequired,
                      };
                    }
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                l.t('save'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
