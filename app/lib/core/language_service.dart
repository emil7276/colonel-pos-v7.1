import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const _key = 'app_language';

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'id';
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language == 'en' ? 'en' : 'id');
  }

  static Future<bool> isEnglish() async {
    return (await getLanguage()) == 'en';
  }
}
