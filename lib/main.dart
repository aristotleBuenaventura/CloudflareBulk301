import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'constants/app_window_sizes.dart';
import 'providers/app_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(AppWindowSizes.login);
  }

  runApp(const Seo301RedirectsApp());
}

class Seo301RedirectsApp extends StatelessWidget {
  const Seo301RedirectsApp({super.key});

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF6821F),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(SessionService()),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'SEO 301 Redirects',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: provider.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AppProvider>().isAuthenticated;
    return isAuthenticated
        ? const HomeShell()
        : const LoginScreen();
  }
}
