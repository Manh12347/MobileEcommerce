import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
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
  }

  void goToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
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
