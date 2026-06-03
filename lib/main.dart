import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:roadrescue_shared/config/app_constants.dart';
import 'package:roadrescue_shared/config/app_env.dart';
import 'package:roadrescue_shared/services/localization_service.dart';
import 'package:roadrescue_shared/services/notification_service.dart';
import 'package:roadrescue_shared/services/stripe_service.dart';
import 'package:roadrescue_shared/services/supabase_service.dart';
import 'package:roadrescue_shared/services/theme_service.dart';
import 'package:roadrescue_shared/widgets/custom_error_widget.dart';
import 'core/app_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Avoid google_fonts disk cache (path_provider JNI / libdartjni.so fails on some Android targets)
  if (!kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  // Load credentials from --dart-define or --dart-define-from-file
  AppEnv.load();

  // 1. Initialize Supabase (CRITICAL)
  await SupabaseService.initialize();

  // If Supabase failed to initialize, we show a special Setup screen
  if (!SupabaseService.isInitialized) {
    runApp(const SetupRequiredApp());
    return;
  }

  // 2. Initialize Other Services
  try {
    await StripeService.initialize();
  } catch (e) {
  }

  try {
    await LocalizationService.instance.initialize();
  } catch (e) {
  }

  try {
    final vsRaw = await SupabaseService.instance.getAppSetting('vehicle_size_translations');
    AppConstants.setVehicleSizeTranslations(vsRaw);
  } catch (e) {
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
  }

  try {
    await ThemeService.instance.initialize();
  } catch (e) {
  }

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return const SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const MyApp());
}

/// A fallback app shown when Supabase configuration is missing.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings_suggest_rounded,
                  size: 80,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(height: 24),
                const Text(
                  'RoadRescue Setup Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B4B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add SUPABASE_URL and SUPABASE_ANON_KEY to env.json in the project root, then restart.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to fix:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Go to your Supabase Dashboard',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '2. Copy Project URL and Anon Key',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '3. Save as env.json and run: flutter run',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

final _navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Set up notification listener based on auth state
    _authSubscription = SupabaseService.instance.authStateChanges.listen((
      data,
    ) {
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
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'roadrescue',
          // Base theme — overridden dynamically inside builder
          theme: AppTheme.buildTheme(
            primary: AppTheme.primary,
            secondary: AppTheme.secondary,
          ),
          themeMode: ThemeMode.light,
          supportedLocales: LocalizationService.instance.enabledLanguages.keys
              .map((code) => Locale(code))
              .toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return ListenableBuilder(
              listenable: Listenable.merge([
                LocalizationService.instance,
                ThemeService.instance,
              ]),
              builder: (context, _) {
                final themeData = AppTheme.buildTheme(
                  primary: ThemeService.instance.primaryColor,
                  secondary: ThemeService.instance.secondaryColor,
                );

                // Apply background color or image from ThemeService
                final bgColor = ThemeService.instance.bgColor;
                final bgImageUrl = ThemeService.instance.bgImageUrl;

                // Build theme with background color
                final themedData = themeData.copyWith(
                  scaffoldBackgroundColor: bgColor ?? themeData.scaffoldBackgroundColor,
                );

                // Build the main app content
                Widget themedChild = child!;

                // Apply global background using Stack - background at bottom, app on top
                if (bgImageUrl.isNotEmpty) {
                  themedChild = Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background layer
                      Container(
                        decoration: BoxDecoration(
                          color: themedData.scaffoldBackgroundColor,
                          image: DecorationImage(
                            image: NetworkImage(bgImageUrl),
                            fit: BoxFit.cover,
                            opacity: 0.15,
                          ),
                        ),
                      ),
                      // App content layer
                      themedChild,
                    ],
                  );
                } else if (bgColor != null) {
                  themedChild = Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background layer
                      Container(color: bgColor),
                      // App content layer
                      themedChild,
                    ],
                  );
                }

                return Theme(
                  data: themedData.copyWith(
                    // Make scaffold backgrounds transparent so background shows through
                    scaffoldBackgroundColor: bgColor != null ? Colors.transparent : themedData.scaffoldBackgroundColor,
                  ),
                  child: Localizations.override(
                    context: context,
                    locale: LocalizationService.instance.currentLocale,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(1.0),
                      ),
                      child: themedChild,
                    ),
                  ),
                );
              },
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          initialRoute: AppRoutes.initial,
        );
      },
    );
  }
}
