import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/login_provider.dart';
import 'screens/login_screen.dart';

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
      ],
      child: MaterialApp(
        title: 'TechShop',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

