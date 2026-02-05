import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Added for Logic
import 'package:agriyukt_app/features/onboarding/onboarding_controller.dart';
import 'package:agriyukt_app/core/constants/app_strings.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  /// ✅ Helper Function: Saves flag and goes to Login
  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true); // Mark as seen

    if (context.mounted) {
      // Navigate to Login (using the route name defined in main.dart)
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<OnboardingController>(context);
    final lang = ctrl.selectedLanguage.isEmpty ? 'en' : ctrl.selectedLanguage;
    final strings = AppStrings.languages[lang] ?? AppStrings.languages['en']!;

    // Colorful Data for "Cartoon-like" feel
    final List<Map<String, dynamic>> slides = [
      {
        "title": strings['slide1_title'],
        "desc": strings['slide1_desc'],
        "icon": Icons.storefront_rounded,
        "color": Colors.orange.shade100,
        "iconColor": Colors.orange.shade700,
      },
      {
        "title": strings['slide2_title'],
        "desc": strings['slide2_desc'],
        "icon": Icons.people_alt_rounded,
        "color": Colors.green.shade100,
        "iconColor": Colors.green.shade700,
      },
      {
        "title": strings['slide3_title'],
        "desc": strings['slide3_desc'],
        "icon": Icons.verified_user_rounded,
        "color": Colors.blue.shade100,
        "iconColor": Colors.blue.shade700,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Animation Blob (Static decoration)
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Bar (Skip Button)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20, top: 10),
                    child: TextButton(
                      // ✅ UPDATED: Call local finish function
                      onPressed: () => _finishOnboarding(context),
                      child: Text(strings['skip']!,
                          style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ),

                // 2. Slide Content
                Expanded(
                  child: PageView.builder(
                    controller: ctrl.pageController,
                    onPageChanged: ctrl.onPageChanged,
                    itemCount: slides.length,
                    itemBuilder: (context, index) => _buildAttractiveSlide(
                      slides[index]["title"],
                      slides[index]["desc"],
                      slides[index]["icon"],
                      slides[index]["color"],
                      slides[index]["iconColor"],
                    ),
                  ),
                ),

                // 3. Bottom Controls
                Padding(
                  padding:
                      const EdgeInsets.only(left: 30, right: 30, bottom: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animated Dots
                      Row(
                        children: List.generate(
                            3,
                            (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: ctrl.currentPage == index ? 24 : 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: ctrl.currentPage == index
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                )),
                      ),

                      // Big Colorful Next Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 35, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 6,
                          shadowColor: Colors.green.withOpacity(0.4),
                        ),
                        // ✅ UPDATED: Logic to handle Next vs Finish locally
                        onPressed: () {
                          if (ctrl.currentPage == 2) {
                            _finishOnboarding(context);
                          } else {
                            ctrl.nextPage(context);
                          }
                        },
                        child: Text(
                          ctrl.currentPage == 2
                              ? strings['login_caps']!
                              : strings['next']!,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttractiveSlide(String title, String desc, IconData icon,
      Color bgColor, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // "Cartoon-style" Icon Container
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: bgColor.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ]),
            child: Icon(icon, size: 90, color: iconColor),
          ),
          const SizedBox(height: 60),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 17, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}
