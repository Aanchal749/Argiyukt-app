import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator/translator.dart';

// ✅ CORRECT IMPORT PATH
import 'package:agriyukt_app/core/providers/language_provider.dart';

class AiText extends StatefulWidget {
  final String text; // The English text you write in code
  final TextStyle? style;
  final TextAlign? textAlign; // Added helpful parameter

  const AiText(this.text, {super.key, this.style, this.textAlign});

  @override
  State<AiText> createState() => _AiTextState();
}

class _AiTextState extends State<AiText> {
  final GoogleTranslator translator = GoogleTranslator();

  // Logic to translate content
  Future<String> _getTranslation(String targetLang) async {
    // 1. If language is English, return original text immediately
    if (targetLang == 'en') return widget.text;

    try {
      // 2. Call Google Translate API
      var translation = await translator.translate(widget.text, to: targetLang);
      return translation.text;
    } catch (e) {
      return widget.text; // Fallback to English if internet fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Use 'appLocale.languageCode' instead of 'targetLanguage'
    final locale = Provider.of<LanguageProvider>(context).appLocale;
    final langCode = locale.languageCode;

    return FutureBuilder<String>(
      future: _getTranslation(langCode),
      builder: (context, snapshot) {
        // Show translated text if available, otherwise show original
        return Text(
          snapshot.data ?? widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
        );
      },
    );
  }
}
