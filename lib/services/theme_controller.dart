import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required bool isDarkMode}) : _isDarkMode = isDarkMode;

  static const _preferenceKey = 'cafe_dark_mode';

  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_preferenceKey, _isDarkMode);
    if (!saved) {
      throw StateError('Could not save the selected app theme.');
    }
  }
}
