import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/theme/skin_controller.dart';
import 'core/language_service.dart';
import 'features/auth/intro_page.dart';

class ColonelApp extends StatelessWidget {
  const ColonelApp({super.key});

  @override
  Widget build(BuildContext context) {
    LanguageService.load();
    return ValueListenableBuilder<String>(
      valueListenable: SkinController.selectedSkin,
      builder: (context, skinId, _) {
        final skin = SkinController.current;
        return ValueListenableBuilder<String>(
      valueListenable: LanguageService.language,
      builder: (context, language, _) {
        final scheme = ColorScheme.fromSeed(
          seedColor: skin.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: skin.primary,
          secondary: skin.primaryDark,
          surface: skin.surface,
          outline: skin.border,
          outlineVariant: skin.border,
          onSurface: skin.text,
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'COLONEL POS UI.1',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        dialogTheme: DialogThemeData(
          backgroundColor: skin.surface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: skin.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          contentTextStyle: TextStyle(
            color: skin.text,
            fontSize: 15,
          ),
        ),
        scaffoldBackgroundColor: skin.background,
        fontFamily: 'sans-serif',
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.4),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.2),
          titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.25),
          bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.25),
          bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.2),
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: skin.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: skin.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: skin.border, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: skin.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: skin.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: skin.primary, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: skin.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: skin.text,
            side: BorderSide(color: skin.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          backgroundColor: skin.primaryDark,
          surfaceTintColor: skin.primaryDark,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? skin.primary : Colors.white70,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? skin.primary : Colors.white70,
              size: selected ? 25 : 23,
            );
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: skin.surface,
          selectedColor: skin.accentSoft,
          side: BorderSide(color: skin.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: TextStyle(fontWeight: FontWeight.w700, color: skin.text),
        ),
        dividerTheme: DividerThemeData(
          color: skin.border,
          space: 1,
          thickness: 1,
        ),
      ),
        home: const IntroPage(),
      );
      },
    );
      },
    );
  }
}
