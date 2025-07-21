import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_with_navigation.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeSettings();
  runApp(QRCodeApp(themeProvider: themeProvider));
}

class QRCodeApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  
  const QRCodeApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'QR Code Creator',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeWithNavigation(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
