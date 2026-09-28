import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._internal();
  ThemeService._internal();

  bool _isDarkMode = true; // Default to dark mode for the premium look
  bool get isDarkMode => _isDarkMode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('murtitrack_is_dark') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('murtitrack_is_dark', _isDarkMode);
    notifyListeners();
  }

  // Common Colors
  static const primaryColor = Color(0xFFD35400); // Deep Orange
  static const secondaryColor = Color(0xFFF39C12); // Amber

  // Dark Theme Colors
  static const darkBackground = Color(0xFF0F0F17);
  static const darkCard = Color(0xFF181824);
  static const darkText = Colors.white;
  static const darkTextSecondary = Colors.white70;

  // Light Theme Colors
  static const lightBackground = Color(0xFFF5F6FA);
  static const lightCard = Colors.white;
  static const lightText = Color(0xFF1A1A24);
  static const lightTextSecondary = Color(0xFF6B6B7A);

  ThemeData get currentTheme {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkCard,
      onSurface: darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: secondaryColor),
      titleTextStyle: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black45,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF222232),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Colors.white38),
      labelStyle: const TextStyle(color: Colors.white70),
    ),
  );

  final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: lightCard,
      onSurface: lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryColor),
      titleTextStyle: TextStyle(color: lightText, fontSize: 18, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black12,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEAEAEE),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: const TextStyle(color: Colors.black38),
      labelStyle: const TextStyle(color: Colors.black54),
    ),
  );
}
