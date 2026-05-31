import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../utils/app_globals.dart';
import '../widgets/app_bottom_nav.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShellScreen> createState() => MainShellScreenState();
}

class MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart(silent: true);
    });
    // Listen for external requests to switch tabs (e.g., Buy Now actions)
    navigateToTabNotifier.addListener(_handleTabNavigation);
  }

  void _handleTabNavigation() {
    final idx = navigateToTabNotifier.value;
    if (idx != null && mounted) {
      // Schedule the tab change on the next frame to ensure navigation is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          goToTab(idx);
          // Clear after handling to prevent duplicate navigation
          navigateToTabNotifier.value = null;
        }
      });
    }
  }

  @override
  void dispose() {
    navigateToTabNotifier.removeListener(_handleTabNavigation);
    super.dispose();
  }

  void goToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() => _currentIndex = index);
    if (index == 2) {
      // Ensure cart is loaded when switching to Cart tab programmatically
      try {
        context.read<CartProvider>().loadCart(silent: true);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onNavigateToTab: goToTab),
          CategoriesScreen(),
          CartScreen(),
          OrdersScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        cartBadgeCount: cartCount,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            context.read<CartProvider>().loadCart(silent: true);
          }
        },
      ),
    );
  }
}
