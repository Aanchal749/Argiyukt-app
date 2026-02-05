import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- PROVIDERS ---
import 'package:agriyukt_app/core/providers/language_provider.dart';

// --- CONTROLLERS ---
import 'package:agriyukt_app/features/auth/controllers/login_controller.dart';
import 'package:agriyukt_app/features/onboarding/onboarding_controller.dart';

// --- SCREENS (Auth & Onboarding) ---
import 'package:agriyukt_app/features/onboarding/screens/splash_screen.dart';
import 'package:agriyukt_app/features/onboarding/screens/language_screen.dart';
import 'package:agriyukt_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/auth/screens/forgot_password_screen.dart';
import 'package:agriyukt_app/features/auth/screens/registration/create_account/create_account_screen.dart';

// --- DASHBOARDS (Role Based) ---
import 'package:agriyukt_app/features/farmer/screens/farmer_layout.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_dashboard.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase (Use your exact URL and Key)
  await Supabase.initialize(
    url: 'https://lyrbnrazuxjilbhdylwt.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5cmJucmF6dXhqaWxiaGR5bHd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1OTE2MDQsImV4cCI6MjA4MjE2NzYwNH0.5HzDWNcNZD5kZw89QNsJFQhnbZwtVx2CMoRzaBZBmHk',
  );

  // 2. Load Saved Language Preference
  final languageProvider = LanguageProvider();
  await languageProvider.loadSavedLanguage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => languageProvider),
        ChangeNotifierProvider(create: (_) => LoginController()),
        ChangeNotifierProvider(create: (_) => OnboardingController()),
      ],
      child: const AgriYuktApp(),
    ),
  );
}

class AgriYuktApp extends StatelessWidget {
  const AgriYuktApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to Language Provider for dynamic locale changes
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriYukt',

      // --- THEME ---
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),

      // --- LOCALIZATION ---
      locale: languageProvider.appLocale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('mr', 'IN'), // Marathi
        Locale('hi', 'IN'), // Hindi
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // --- ROUTE MAP ---
      // This map allows you to navigate using strings (e.g. Navigator.pushNamed)
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/language': (context) => const LanguageScreen(fromProfile: false),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/create-account': (context) => const CreateAccountScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),

        // Dashboards
        '/farmer-dashboard': (context) => const FarmerLayout(),
        '/buyer-dashboard': (context) => const BuyerDashboard(),
        '/inspector-dashboard': (context) => const InspectorLayout(),
      },

      // --- ENTRY POINT ---
      // Instead of a static screen, we use the FlowOrchestrator to decide where to go
      home: const FlowOrchestrator(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// THE FLOW ORCHESTRATOR
/// This widget runs the logic: Splash -> Language -> Onboarding -> Auth -> Dashboard
/// ---------------------------------------------------------------------------
class FlowOrchestrator extends StatefulWidget {
  const FlowOrchestrator({super.key});

  @override
  State<FlowOrchestrator> createState() => _FlowOrchestratorState();
}

class _FlowOrchestratorState extends State<FlowOrchestrator> {
  @override
  void initState() {
    super.initState();
    _startAppFlow();
  }

  Future<void> _startAppFlow() async {
    // 1. Show Splash Screen for 2 seconds (visual requirement)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. Get User Preferences & Auth Session
    final prefs = await SharedPreferences.getInstance();
    final session = Supabase.instance.client.auth.currentSession;

    // --- CHECK 1: LANGUAGE ---
    // Has the user ever selected a language?
    final bool isLanguageSet = prefs.getBool('isLanguageSet') ?? false;

    if (!isLanguageSet) {
      // Logic: User is new -> Go to Language Screen
      if (mounted) Navigator.pushReplacementNamed(context, '/language');
      return;
    }

    // --- CHECK 2: ONBOARDING ---
    // Has the user seen the onboarding slider?
    final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

    if (!seenOnboarding) {
      // Logic: User selected language but hasn't seen intro -> Go to Onboarding
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    // --- CHECK 3: AUTHENTICATION ---
    // Is the user logged in?
    if (session != null) {
      // Logic: User is logged in -> Determine Role and go to Dashboard
      await _navigateToRoleDashboard(session.user.id);
    } else {
      // Logic: User is NOT logged in -> Go to Login Screen
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  /// Helper to fetch user role and redirect
  Future<void> _navigateToRoleDashboard(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      final role = data?['role']?.toString().toLowerCase().trim() ?? 'farmer';

      if (!mounted) return;

      if (role == 'buyer') {
        Navigator.pushReplacementNamed(context, '/buyer-dashboard');
      } else if (role == 'inspector') {
        Navigator.pushReplacementNamed(context, '/inspector-dashboard');
      } else {
        // Default to Farmer if role is farmer or unknown
        Navigator.pushReplacementNamed(context, '/farmer-dashboard');
      }
    } catch (e) {
      // Safety Fallback: If DB check fails, go to Login
      debugPrint("Auth Flow Error: $e");
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // While _startAppFlow runs, the user sees the Splash Screen
    return const SplashScreen();
  }
}
