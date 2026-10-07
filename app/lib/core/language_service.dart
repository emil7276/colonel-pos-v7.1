import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const _key = 'app_language';

  static final ValueNotifier<String> language = ValueNotifier<String>('id');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    language.value = prefs.getString(_key) == 'en' ? 'en' : 'id';
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'id';
  }

  static Future<void> setLanguage(String value) async {
    final next = value == 'en' ? 'en' : 'id';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next);

    language.value = next;
  }

  static bool get isEnglish => language.value == 'en';
}
