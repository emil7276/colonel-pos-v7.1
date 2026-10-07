import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/language_service.dart';
import 'features/auth/intro_page.dart';

class ColonelApp extends StatelessWidget {
  const ColonelApp({super.key});

  @override
  Widget build(BuildContext context) {
    LanguageService.load();
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.language,
      builder: (context, language, _) {
        final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CP POS 6.5 GOLD',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: pageBg,
        fontFamily: 'sans-serif-condensed',
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
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: gold),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: boxBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
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
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: red, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: ink,
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
            foregroundColor: goldDeep,
            side: const BorderSide(color: goldDeep),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 76,
          backgroundColor: navy,
          surfaceTintColor: navy,
          indicatorColor: gold.withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? gold : Colors.white70,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? gold : Colors.white70,
              size: selected ? 25 : 23,
            );
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: gold.withValues(alpha: .18),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: ink),
        ),
        dividerTheme: const DividerThemeData(
          color: line,
          space: 1,
          thickness: 1,
        ),
      ),
        home: const IntroPage(),
      );
      },
    );
  }
}
