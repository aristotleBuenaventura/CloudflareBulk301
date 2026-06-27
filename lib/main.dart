import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/bulk_redirect_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_service.dart';

void main() {
  runApp(const CloudflareBulk301App());
}

class CloudflareBulk301App extends StatelessWidget {
  const CloudflareBulk301App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(SessionService()),
      child: MaterialApp(
        title: 'Cloudflare Bulk 301',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF6821F),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF6821F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
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
        ? const BulkRedirectScreen()
        : const LoginScreen();
  }
}
