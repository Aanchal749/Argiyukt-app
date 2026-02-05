import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:agriyukt_app/core/constants/app_strings.dart';
import 'package:agriyukt_app/core/providers/language_provider.dart';

class LanguageScreen extends StatefulWidget {
  final bool fromProfile;

  const LanguageScreen({super.key, this.fromProfile = false});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'en';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedLanguage = prefs.getString('language_code') ?? 'en';
      });
    }
  }

  Future<void> _saveAndProceed() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', _selectedLanguage);

    // ✅ CRITICAL FIX 1: Set the flag so Splash knows language is selected
    await prefs.setBool('isLanguageSet', true);

    if (!mounted) return;

    // Update Provider
    Provider.of<LanguageProvider>(context, listen: false)
        .changeLanguage(_selectedLanguage);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          _selectedLanguage == 'mr' ? "भाषा बदलली!" : "Language Updated!",
          style: GoogleFonts.poppins()),
      backgroundColor: Colors.green,
      duration: const Duration(milliseconds: 800),
    ));

    // ✅ CRITICAL FIX 2: Navigate to Onboarding, NOT Login
    if (widget.fromProfile) {
      Navigator.pop(context, true);
    } else {
      // Use named route to ensure we hit the Onboarding Screen next
      Navigator.pushReplacementNamed(context, '/onboarding');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppStrings.languages[_selectedLanguage] ?? AppStrings.languages['en']!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.fromProfile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _selectedLanguage == 'mr' ? "भाषा निवडा" : "Select Language",
                style: GoogleFonts.poppins(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              if (!widget.fromProfile) const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5)
                  ],
                ),
                child: const Icon(Icons.translate_rounded,
                    size: 70, color: Colors.green),
              ),
              const SizedBox(height: 30),
              Text(
                widget.fromProfile
                    ? (_selectedLanguage == 'mr'
                        ? "भाषा बदला"
                        : "Change Language")
                    : strings['welcome_msg']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              const SizedBox(height: 10),
              Text(
                strings['select_lang']!,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),
              _buildLangOption("English", "en"),
              const SizedBox(height: 15),
              _buildLangOption("मराठी (Marathi)", "mr"),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: Colors.green.withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _saveAndProceed,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.fromProfile
                              ? (_selectedLanguage == 'mr'
                                  ? "बदल जतन करा"
                                  : "Save Changes")
                              : strings['get_started']!,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangOption(String name, String code) {
    bool selected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguage = code;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? Colors.green.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: selected ? Colors.green : Colors.grey.shade200, width: 2),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.green : Colors.black87),
            ),
            const Spacer(),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? Colors.green : Colors.grey.shade400,
            )
          ],
        ),
      ),
    );
  }
}
