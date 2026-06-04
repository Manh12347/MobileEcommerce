import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';
import 'providers/chat_session_provider.dart';
import 'providers/login_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_view_history_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductViewHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ChatSessionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'TechShop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
          useMaterial3: true,
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginProvider>();

    if (login.isRestoringSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F8FC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
        ),
      );
    }

    final hasSession =
        login.loginResponse?.accessToken != null &&
        login.loginResponse!.accessToken!.isNotEmpty;

    return hasSession ? const MainShellScreen() : const LoginScreen();
  }
}
