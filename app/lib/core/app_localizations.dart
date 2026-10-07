import 'language_service.dart';

class AppLocalizations {
  static String get language => LanguageService.language.value;

  static bool get isEnglish => language == 'en';

  static String t(String id, String en) {
    return isEnglish ? en : id;
  }
}
