import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  String _lang = 'en';

  Future<void> _setLang(String code) async {
    setState(() => _lang = code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', code);
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void _finishOnboarding() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Skip Button)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.agriculture, color: Colors.green, size: 30),
                  if (_currentPage > 0 && _currentPage < 3)
                    TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text("Skip")),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                physics:
                    const NeverScrollableScrollPhysics(), // Prevent manual swipe on lang page
                children: [
                  // Page 1: Language Selection
                  _buildLanguagePage(),

                  // Page 2: Demand & Supply
                  _buildInfoPage(
                    icon: Icons.bar_chart,
                    title:
                        _lang == 'en' ? "Demand & Supply" : "मागणी आणि पुरवठा",
                    desc: _lang == 'en'
                        ? "Analyze market trends effectively."
                        : "बाजारातील कल प्रभावीपणे विश्लेषित करा.",
                  ),

                  // Page 3: Real-time Connection
                  _buildInfoPage(
                    icon: Icons.sync_alt,
                    title: _lang == 'en'
                        ? "Real-time Connection"
                        : "रिअल-टाइम कनेक्शन",
                    desc: _lang == 'en'
                        ? "Connect buyers and farmers instantly."
                        : "शेतकरी आणि खरेदीदारांना त्वरित जोडा.",
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Dots Indicator
            if (_currentPage > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    2,
                    (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (index == _currentPage - 1)
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                        )),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Welcome to AgriYukt",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
        const SizedBox(height: 40),
        const Text("Select Your Language / भाषा निवडा",
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => _setLang('en'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green)),
          child: const Text("English"),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _setLang('mr'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green)),
          child: const Text("मराठी"),
        ),
      ],
    );
  }

  Widget _buildInfoPage(
      {required IconData icon,
      required String title,
      required String desc,
      bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Colors.green),
          const SizedBox(height: 40),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 16),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const Spacer(),
          if (isLast)
            ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(_lang == 'en' ? "Get Started" : "सुरु करा",
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            )
          else
            ElevatedButton(
              onPressed: () => _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(_lang == 'en' ? "Next" : "पुढे",
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
