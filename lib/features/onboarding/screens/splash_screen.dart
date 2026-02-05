import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added Typography Support

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Bloom Animation
    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo);
    _controller.forward();

    // 2. Init App
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Check if Supabase is already initialized to prevent errors during hot restart
      if (Supabase.instance.client.auth.currentUser == null &&
          false /* Force check if needed */) {
        // This block is just a placeholder safety check
      }
    } catch (_) {
      // If instance access fails, we initialize
    }

    try {
      // Only initialize if not already done (Supabase throws if init called twice)
      await Supabase.initialize(
        url: 'https://lyrbnrazuxjilbhdylwt.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5cmJucmF6dXhqaWxiaGR5bHd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1OTE2MDQsImV4cCI6MjA4MjE2NzYwNH0.5HzDWNcNZD5kZw89QNsJFQhnbZwtVx2CMoRzaBZBmHk',
      );
    } catch (e) {
      // Ignore error if already initialized
      debugPrint("Supabase Init Warning (Safe to ignore): $e");
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    // ✅ LOGIC: Check session and redirect
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // User is logged in -> Go to Dashboard (Logic preserved)
      // Ideally, you should check the role here to redirect to specific dashboards
      Navigator.pushReplacementNamed(context, '/farmer-dashboard');
    } else {
      // User is NOT logged in -> Go to Language Selection
      Navigator.pushReplacementNamed(context, '/language');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                    color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.agriculture_rounded,
                    size: 80, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                "AgriYukt",
                style: GoogleFonts.poppins(
                  // ✅ Added Typography
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
