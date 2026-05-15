import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:supabase_flutter/supabase_flutter.dart';

import './services/localization_service.dart';
import './services/notification_service.dart';
import './services/supabase_service.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  // Initialize Stripe
  try {
    Stripe.publishableKey = const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
      defaultValue: '',
    );
    if (kIsWeb) {
      await Stripe.instance.applySettings();
    }
  } catch (e) {
    debugPrint('Failed to initialize Stripe: $e');
  }

  // Initialize Localization
  try {
    await LocalizationService.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize localization: $e');
  }

  // Initialize Notifications
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  // SystemChrome.setPreferredOrientations is a no-op on web and must be
  // guarded so runApp() is never blocked by a web-unsupported future.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static State<MyApp>? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _locale = LocalizationService.instance.currentLocale;
    LocalizationService.instance.addListener(_onLocaleChanged);

    // Set up notification listener based on auth state
    _authSubscription = SupabaseService.instance.authStateChanges.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        NotificationService.instance.startListening(user.id);
      } else {
        NotificationService.instance.stopListening();
      }
    });

    // Initial check
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      NotificationService.instance.startListening(user.id);
    }
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() => _locale = LocalizationService.instance.currentLocale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'roadrescue',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          locale: _locale,
          supportedLocales: LocalizationService.supportedLanguages.keys
              .map((code) => Locale(code))
              .toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          routes: AppRoutes.routes,
          initialRoute: AppRoutes.initial,
        );
      },
    );
  }
}
