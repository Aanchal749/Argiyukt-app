import 'package:flutter/material.dart';
// ✅ CORRECTED IMPORT
import 'package:agriyukt_app/features/auth/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({super.key}); // ✅ No const

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {"title": "Welcome", "desc": "AgriYukt Marketplace", "icon": "eco"},
    {"title": "Fair Price", "desc": "Transparent Pricing", "icon": "price"},
    {"title": "Verified", "desc": "Quality Assured", "icon": "check"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (ctx, i) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, size: 100, color: Colors.green),
                  Text(
                    _pages[i]['title']!,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(_pages[i]['desc']!),
                ],
              ),
            ),
          ),
          ElevatedButton(
            // ✅ REMOVED CONST
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            ),
            child: Text("Get Started"),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }
}
