import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loginResponse = context.watch<LoginProvider>().loginResponse;
    final email = loginResponse?.email ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TechShop'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF1976D2),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Login successful',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
