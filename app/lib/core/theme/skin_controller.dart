import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SkinPalette {
  final String name;
  final Color background;
  final Color surface;
  final Color primary;
  final Color primaryDark;
  final Color accentSoft;
  final Color border;
  final Color text;
  final Color mutedText;

  const SkinPalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.accentSoft,
    required this.border,
    this.text = const Color(0xFF20242A),
    this.mutedText = const Color(0xFF6F7782),
  });
}

class SkinController {
  static const String _storageKey = 'cp_pos_selected_skin';

  static const String oceanBlue = 'ocean_blue';
  static const String colonelRed = 'colonel_red';
  static const String classicBrown = 'classic_brown';
  static const String lavenderPurple = 'lavender_purple';
  static const String aquaTeal = 'aqua_teal';
  static const String pink = 'pink';

  static const Map<String, SkinPalette> palettes = {
    oceanBlue: SkinPalette(
      name: 'Ocean Blue',
      background: Color(0xFFE8EDF3),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFF3478B8),
      primaryDark: Color(0xFF173B60),
      accentSoft: Color(0xFFC7D5E5),
      border: Color(0xFFD1D9E2),
    ),
    colonelRed: SkinPalette(
      name: 'Colonel Red',
      background: Color(0xFFE8E8E8),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFFB9272D),
      primaryDark: Color(0xFF70191D),
      accentSoft: Color(0xFFF8DADD),
      border: Color(0xFFD2D2D2),
    ),
    classicBrown: SkinPalette(
      name: 'Classic Brown',
      background: Color(0xFFEDE2D3),
      surface: Color(0xFFFFF9F1),
      primary: Color(0xFF896044),
      primaryDark: Color(0xFF4B3024),
      accentSoft: Color(0xFFD4B99C),
      border: Color(0xFFDCCBBC),
    ),
    lavenderPurple: SkinPalette(
      name: 'Lavender Purple',
      background: Color(0xFFEAE5F5),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFF8064B5),
      primaryDark: Color(0xFF44305F),
      accentSoft: Color(0xFFCFC2E8),
      border: Color(0xFFD9D0E9),
    ),
    pink: SkinPalette(
      name: 'Pink',
      background: Color(0xFFF8E7EF),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFFD85A91),
      primaryDark: Color(0xFF8F315B),
      accentSoft: Color(0xFFF3C4D8),
      border: Color(0xFFE8C9D7),
    ),
    aquaTeal: SkinPalette(
      name: 'Aqua Teal',
      background: Color(0xFFDFF2F5),
      surface: Color(0xFFFFFFFF),
      primary: Color(0xFF168F9A),
      primaryDark: Color(0xFF14545C),
      accentSoft: Color(0xFFA8DCE0),
      border: Color(0xFFC5E2E6),
    ),
  };

  static final ValueNotifier<String> selectedSkin =
      ValueNotifier<String>(oceanBlue);

  static SkinPalette get current =>
      palettes[selectedSkin.value] ?? palettes[oceanBlue]!;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSkin = prefs.getString(_storageKey);

    if (savedSkin != null && palettes.containsKey(savedSkin)) {
      selectedSkin.value = savedSkin;
    }
  }

  static Future<void> setSkin(String skinId) async {
    if (!palettes.containsKey(skinId)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, skinId);
    selectedSkin.value = skinId;
  }
}
