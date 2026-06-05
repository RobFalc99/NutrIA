import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_mode_dark';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
  }
}

/// Extension per ottenere i colori del tema corrente facilmente
extension AppThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Sfondi
  Color get bgPrimary => isDark ? const Color(0xFF0F0F13) : const Color(0xFFF2F4F8);
  Color get bgCard => isDark ? const Color(0xFF16161D) : const Color(0xFFFFFFFF);
  Color get bgCardAlt => isDark ? const Color(0xFF1C1C24) : const Color(0xFFEFF1F7);

  // Testi
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF5A5A7A);
  Color get textMuted => isDark ? Colors.white38 : const Color(0xFF9090AA);

  // Bordi
  Color get borderColor => isDark
      ? Colors.white.withAlpha(15)
      : const Color(0xFF1A1A2E).withAlpha(20);

  // Accent - uguali in entrambi i temi
  Color get accentCyan => const Color(0xFF00FFC2);
  Color get accentPink => const Color(0xFFFF007F);
  Color get accentYellow => const Color(0xFFFFD700);
  Color get accentGreen => const Color(0xFF00E676);
}
