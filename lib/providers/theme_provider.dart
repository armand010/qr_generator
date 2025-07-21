import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeColorKey = 'theme_color';
  static const String _isDarkModeKey = 'is_dark_mode';
  
  Color _primaryColor = Colors.green;
  bool _isDarkMode = false;
  
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;
  
  // Available theme colors
  static const List<Color> availableColors = [
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
  ];
  
  static const List<String> colorNames = [
    'Green',
    'Blue', 
    'Purple',
    'Orange',
    'Red',
    'Teal',
    'Indigo',
    'Pink',
    'Amber',
    'Cyan',
  ];
  
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _getMaterialColor(_primaryColor),
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: _getMaterialColor(_primaryColor),
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey[900],
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;
  
  // Helper method to create MaterialColor from Color
  MaterialColor _getMaterialColor(Color color) {
    final int red = color.red;
    final int green = color.green;
    final int blue = color.blue;
    
    final Map<int, Color> shades = {
      50: Color.fromRGBO(red, green, blue, .1),
      100: Color.fromRGBO(red, green, blue, .2),
      200: Color.fromRGBO(red, green, blue, .3),
      300: Color.fromRGBO(red, green, blue, .4),
      400: Color.fromRGBO(red, green, blue, .5),
      500: Color.fromRGBO(red, green, blue, .6),
      600: Color.fromRGBO(red, green, blue, .7),
      700: Color.fromRGBO(red, green, blue, .8),
      800: Color.fromRGBO(red, green, blue, .9),
      900: Color.fromRGBO(red, green, blue, 1),
    };
    
    return MaterialColor(color.value, shades);
  }
  
  // Load theme settings from shared preferences
  Future<void> loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load color
    final colorIndex = prefs.getInt(_themeColorKey) ?? 0;
    if (colorIndex < availableColors.length) {
      _primaryColor = availableColors[colorIndex];
    }
    
    // Load dark mode
    _isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
    
    notifyListeners();
  }
  
  // Save theme settings to shared preferences
  Future<void> _saveThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final colorIndex = availableColors.indexOf(_primaryColor);
    await prefs.setInt(_themeColorKey, colorIndex);
    await prefs.setBool(_isDarkModeKey, _isDarkMode);
  }
  
  // Change primary color
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _saveThemeSettings();
    notifyListeners();
  }
  
  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeSettings();
    notifyListeners();
  }
  
  // Set dark mode
  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _saveThemeSettings();
    notifyListeners();
  }
  
  // Get color name
  String getColorName(Color color) {
    final index = availableColors.indexOf(color);
    if (index != -1 && index < colorNames.length) {
      return colorNames[index];
    }
    return 'Custom';
  }
}
