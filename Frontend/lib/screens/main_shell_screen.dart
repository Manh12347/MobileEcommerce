import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../providers/login_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/app_globals.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat_bubble.dart';
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
      context.read<NotificationProvider>().loadUnreadCount();
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
    _switchTab(index);
  }

  void _switchTab(int index) {
    context.read<LoginProvider>().clearError();
    context.read<CartProvider>().clearError();
    setState(() => _currentIndex = index);
    if (index == 2) {
      // Ensure cart is loaded when switching to Cart tab programmatically
      try {
        context.read<CartProvider>().loadCart(silent: true);
      } catch (_) {}
    } else if (index == 3) {
      refreshOrdersNotifier.value++;
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
        onTap: _switchTab,
      ),
      floatingActionButton: _shouldShowChatbot
          ? const ChatBubbleButton()
          : null,
    );
  }

  bool get _shouldShowChatbot => _currentIndex == 0 || _currentIndex == 1;
}
