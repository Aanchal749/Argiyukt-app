import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // ✅ VISUALS ONLY. No Logic. No Navigation.
    // The 'FlowOrchestrator' in main.dart handles the logic while this animation plays.
    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo);
    _controller.forward();
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
