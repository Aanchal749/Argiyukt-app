import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

// --- PROVIDERS ---
import 'package:agriyukt_app/core/providers/language_provider.dart';

// --- CONTROLLERS ---
import 'package:agriyukt_app/features/auth/controllers/login_controller.dart';
import 'package:agriyukt_app/features/onboarding/onboarding_controller.dart';

// --- SCREENS ---
import 'package:agriyukt_app/features/onboarding/screens/splash_screen.dart';
import 'package:agriyukt_app/features/onboarding/screens/language_screen.dart';
import 'package:agriyukt_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';
import 'package:agriyukt_app/features/auth/screens/forgot_password_screen.dart';
import 'package:agriyukt_app/features/auth/screens/registration/create_account/create_account_screen.dart';

// --- DASHBOARDS ---
import 'package:agriyukt_app/features/farmer/screens/farmer_layout.dart';
import 'package:agriyukt_app/features/buyer/screens/buyer_dashboard.dart';
import 'package:agriyukt_app/features/inspector/screens/inspector_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: 'https://lyrbnrazuxjilbhdylwt.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5cmJucmF6dXhqaWxiaGR5bHd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1OTE2MDQsImV4cCI6MjA4MjE2NzYwNH0.5HzDWNcNZD5kZw89QNsJFQhnbZwtVx2CMoRzaBZBmHk',
  );

  // 2. Load Saved Language (for text translation only)
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
        Locale('mr', 'IN'),
        Locale('hi', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // --- ROUTES ---
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
      home: const FlowOrchestrator(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// THE FLOW ORCHESTRATOR
/// Strictly implements: Token ? Dashboard : Language -> Onboarding -> Login
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
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    // 1. Always show Splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. CHECK LOGIN STATUS
    // We check Supabase Session. If it exists, user is "Logged In".
    // If it is null, user is "Not Logged In".
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // ─────────────────────────────────────────────────────────────
      // CASE 1: LOGGED IN
      // Flow: Splash -> Dashboard
      // ─────────────────────────────────────────────────────────────
      debugPrint("✅ User Logged In. Navigating to Dashboard...");
      await _navigateToRoleDashboard(session.user.id);
    } else {
      // ─────────────────────────────────────────────────────────────
      // CASE 2: NOT LOGGED IN (or Logged Out)
      // Flow: Splash -> Language -> Onboarding -> Login
      // ─────────────────────────────────────────────────────────────
      debugPrint("❌ User Not Logged In. Starting Fresh Flow...");

      // Go to Language Screen
      // (Language Screen must have a button to go to '/onboarding')
      if (mounted) Navigator.pushReplacementNamed(context, '/language');
    }
  }

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
        Navigator.pushReplacementNamed(context, '/farmer-dashboard');
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
      // Fallback: If network fails, treat as not logged in
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
