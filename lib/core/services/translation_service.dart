import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  // ✅ Renamed to 'toEnglish' to match your screens
  static Future<String> toEnglish(String input) async {
    if (input.trim().isEmpty) return "";
    try {
      var translation = await _translator.translate(input, to: 'en');
      return translation.text;
    } catch (e) {
      return input; // Return original if offline/error
    }
  }

  // ✅ Renamed to 'toLocal' to match your screens
  static Future<String> toLocal(String input, String targetLang) async {
    if (input.trim().isEmpty || targetLang == 'en') return input;
    try {
      var translation = await _translator.translate(input, to: targetLang);
      return translation.text;
    } catch (e) {
      return input;
    }
  }
}
