import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agriyukt_app/features/auth/controllers/login_controller.dart';
import 'package:agriyukt_app/features/onboarding/onboarding_controller.dart';
import 'package:agriyukt_app/core/constants/app_strings.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added Typography Support

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<LoginController>(context, listen: false);
    final onboardingCtrl =
        Provider.of<OnboardingController>(context, listen: false);

    // Get Selected Language Logic
    final lang = onboardingCtrl.selectedLanguage.isEmpty
        ? 'en'
        : onboardingCtrl.selectedLanguage;
    final str = AppStrings.languages[lang] ?? AppStrings.languages['en']!;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // ✅ Added SafeArea to prevent system bar overlap
        child: Center(
          // ✅ Centers content on big screens
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Dynamic Spacing instead of fixed 100
                SizedBox(height: screenHeight * 0.05),
                const Icon(Icons.agriculture, size: 80, color: Colors.green),
                const SizedBox(height: 20),

                // 1. Translated Title
                Text(
                  str['login_title']!,
                  textAlign: TextAlign.center, // ✅ Center align title
                  style: GoogleFonts.poppins(
                      // ✅ Added Typography
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 40),

                // 2. Translated Email Field
                TextField(
                  controller: authCtrl.emailCtrl,
                  style:
                      GoogleFonts.poppins(fontSize: 14), // ✅ Input Text Style
                  decoration: InputDecoration(
                    labelText: str['email_phone'], // "ईमेल किंवा मोबाईल नंबर"
                    labelStyle:
                        GoogleFonts.poppins(fontSize: 14), // ✅ Label Style
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Translated Password Field
                TextField(
                  controller: authCtrl.passCtrl,
                  obscureText: _obscure,
                  style:
                      GoogleFonts.poppins(fontSize: 14), // ✅ Input Text Style
                  decoration: InputDecoration(
                    labelText: str['password'], // "पासवर्ड"
                    labelStyle:
                        GoogleFonts.poppins(fontSize: 14), // ✅ Label Style
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),

                // 4. Translated Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                    child: Text(str['forgot_pass']!, // "पासवर्ड विसरलात?"
                        style: GoogleFonts.poppins(
                            // ✅ Added Typography
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ),
                ),

                const SizedBox(height: 30),

                // 5. Translated Login Button
                Consumer<LoginController>(
                  builder: (ctx, auth, _) => auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.green)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15))),
                          onPressed: () => auth.login(context),
                          child: Text(str['login_btn']!, // "लॉगिन"
                              style: GoogleFonts.poppins(
                                  // ✅ Added Typography
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                ),

                const SizedBox(height: 30),

                // 6. Translated Create Account Text (Protected against overflow)
                Wrap(
                  // ✅ Changed Row to Wrap to prevent horizontal overflow
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      str['no_account']!,
                      style: GoogleFonts.poppins(
                          // ✅ Added Typography
                          color: Colors.black54),
                    ), // "खाते नाही? "
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/create-account'),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Text(
                          str['create_acc']!, // "नवीन खाते तयार करा"
                          style: GoogleFonts.poppins(
                              // ✅ Added Typography
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(height: screenHeight * 0.05), // Bottom spacing
              ],
            ),
          ),
        ),
      ),
    );
  }
}
