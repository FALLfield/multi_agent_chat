import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _prefKey = 'theme_mode';
  bool _initialized = false;

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _load();
  }

  Future<void> _load() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey);
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDarkMode);
  }

  // ==== Gemini Style Themes ====

  ThemeData get darkTheme {
    const bgColor = Color(0xFF131314);
    const surfaceColor = Color(0xFF1E1F22);
    const surfaceVariant = Color(0xFF282A2D);
    const textColor = Color(0xFFE3E3E3);
    const textSecondary = Color(0xFF9AA0A6);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        surface: surfaceColor,
        surfaceContainerHighest: surfaceVariant,
        primary: Color(0xFFA8C7FA),
        onSurface: textColor,
        secondaryContainer: Color(0xFF1A2744),
        tertiary: Color(0xFF80CBC4),
        outline: Color(0xFF3C4043),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: surfaceVariant,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFFA8C7FA),
        foregroundColor: const Color(0xFF131314),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: surfaceVariant,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3C4043),
        thickness: 0.5,
        space: 1,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get lightTheme {
    const bgColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFF0F4F9);
    const surfaceVariant = Color(0xFFE8ECF1);
    const textColor = Color(0xFF1F1F1F);
    const textSecondary = Color(0xFF5F6368);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.light(
        surface: surfaceColor,
        surfaceContainerHighest: surfaceVariant,
        primary: Color(0xFF0B57D0),
        onSurface: textColor,
        secondaryContainer: Color(0xFFD3E3FD),
        tertiary: Color(0xFF00897B),
        outline: Color(0xFFDADCE0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        color: surfaceVariant,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF0B57D0),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: textColor,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFDADCE0),
        thickness: 0.5,
        space: 1,
      ),
      useMaterial3: true,
    );
  }
}
