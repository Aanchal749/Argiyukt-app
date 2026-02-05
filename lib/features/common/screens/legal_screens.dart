import 'package:flutter/material.dart';

class StaticContentScreen extends StatelessWidget {
  final String title;
  final String content;
  final Color themeColor;

  const StaticContentScreen({
    super.key,
    required this.title,
    required this.content,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content,
          style:
              const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
        ),
      ),
    );
  }
}

// --- CONTENT STRINGS (You can move these to a constants file later) ---
const String kPrivacyPolicy = """
1. Data Collection
We collect personal information to provide better services...

2. Usage
Your data is used for app functionality and order processing...

(This is a placeholder for your full Privacy Policy)
""";

const String kTermsConditions = """
1. Acceptance
By using AgriYukt, you agree to these terms...

2. User Conduct
You agree not to misuse the platform...

(This is a placeholder for your full Terms & Conditions)
""";

const String kAboutApp = """
AgriYukt is a comprehensive platform connecting Farmers, Buyers, and Inspectors.
Version: 1.0.0
Developed by: AgriYukt Team
""";
