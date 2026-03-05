import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ==== Gemini Style Themes ====

  // Gemini's dark theme: Deep space, very dark grays instead of pure black
  ThemeData get darkTheme {
    const bgColor = Color(0xFF131314);
    const surfaceColor = Color(0xFF1E1F22);
    const textColor = Color(0xFFE3E3E3);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        surface: surfaceColor,
        primary: Color(0xFFA8C7FA), // Soft Gemini blue
        onSurface: textColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
      ),
      useMaterial3: true,
    );
  }

  // Gemini's light theme: Clean white with slight off-white surfaces
  ThemeData get lightTheme {
    const bgColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFF0F4F9);
    const textColor = Color(0xFF1F1F1F);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.light(
        surface: surfaceColor,
        primary: Color(0xFF0B57D0),
        onSurface: textColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Color(0xFF444746)),
      ),
      useMaterial3: true,
    );
  }
}
