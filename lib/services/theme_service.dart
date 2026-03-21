import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, cyber }

class ThemeService with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;
  AppTheme get currentTheme => _currentTheme;

  bool get isDarkMode => _currentTheme == AppTheme.dark || _currentTheme == AppTheme.cyber;
  bool get isCyberMode => _currentTheme == AppTheme.cyber;

  ThemeService() {
    _loadTheme();
  }

  void setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('themeMode', theme.index);
  }

  void toggleTheme() {
    if (_currentTheme == AppTheme.light) {
      setTheme(AppTheme.dark);
    } else if (_currentTheme == AppTheme.dark) {
      setTheme(AppTheme.cyber);
    } else {
      setTheme(AppTheme.light);
    }
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    int themeIndex = prefs.getInt('themeMode') ?? 0;
    _currentTheme = AppTheme.values[themeIndex];
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.cyber:
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF00E5FF),
          scaffoldBackgroundColor: const Color(0xFF0A0E21),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1D1E33),
            foregroundColor: Color(0xFF00E5FF),
            elevation: 8,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF1D1E33).withOpacity(0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00E5FF),
            brightness: Brightness.dark,
            secondary: const Color(0xFFFF007F),
          ),
        );
      case AppTheme.dark:
        return ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            foregroundColor: Colors.white,
          ),
        );
      default:
        return ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        );
    }
  }
}
