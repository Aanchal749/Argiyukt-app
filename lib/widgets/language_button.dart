import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageButton extends StatelessWidget {
  final Function(String) onLanguageChanged;

  const LanguageButton({super.key, required this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.green),
      onSelected: (String value) async {
        // 1. Save to Memory
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_language', value);

        // 2. Notify Parent Screen
        onLanguageChanged(value);

        // 3. Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Language changed to $value")),
        );
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'English',
          child: Row(
            children: [Text("🇺🇸  English")],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Hindi',
          child: Row(
            children: [Text("🇮🇳  हिंदी (Hindi)")],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Marathi',
          child: Row(
            children: [Text("🇮🇳  मराठी (Marathi)")],
          ),
        ),
      ],
    );
  }
}
