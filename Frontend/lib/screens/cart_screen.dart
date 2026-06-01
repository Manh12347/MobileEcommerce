import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../providers/cart_provider.dart';
import '../utils/format_utils.dart';
import 'build_compatibility_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Giỏ hàng',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cartProvider.loadCart(),
              color: const Color(0xFF1F67E2),
              child: _buildBody(cartProvider, cart),
            ),
          ),
          if (cart != null && cart.items.isNotEmpty)
            _CartSummaryBar(cart: cart)
          else
            _BuildConfigBar(cart: cart),
        ],
      ),
    );
  }

  Widget _buildBody(CartProvider cartProvider, Cart? cart) {
    if (cartProvider.isLoading && cart == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
      );
    }

    if (cartProvider.errorMessage.isNotEmpty && cart == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              cartProvider.errorMessage,
              style: const TextStyle(color: Color(0xFF6B7893)),
            ),
          ),
        ],
      );
    }

    if (cart == null || cart.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Color(0xFFB8C4DA),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Giỏ hàng trống',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14213D),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: cart.items.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PromotionBanner(cart: cart);
        }
        final item = cart.items[index - 1];
        return _CartItemCard(
          item: item,
          onIncrease: () => cartProvider.updateQuantity(
            cartItemId: item.cartItemId,
            quantity: item.quantity + 1,
          ),
          onDecrease: () => cartProvider.updateQuantity(
            cartItemId: item.cartItemId,
            quantity: item.quantity - 1,
          ),
          onRemove: () => cartProvider.removeItem(item.cartItemId),
        );
      },
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final savings = cart.promotionSavings;
    if (savings <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9D9FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: Color(0xFF1F67E2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Khuyến mãi tự động — tiết kiệm ${formatCurrency(savings)}',
              style: const TextStyle(
                color: Color(0xFF1F67E2),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.mainImageUrl != null && item.mainImageUrl!.isNotEmpty
                ? Image.network(
                    item.mainImageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? 'Sản phẩm',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14213D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku ?? '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7893),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      formatCurrency(item.unitPrice),
                      style: const TextStyle(
                        color: Color(0xFF1F67E2),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.hasPromotion) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(item.price),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF91A0B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove, onTap: onDecrease),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add, onTap: onIncrease),
                    const Spacer(),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                      ),
                      tooltip: 'Xóa',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFE8EEF7),
      child: const Icon(Icons.devices, color: Color(0xFF91A0B8)),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F5FC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: const Color(0xFF1F67E2)),
        ),
      ),
    );
  }
}

class _BuildConfigBar extends StatelessWidget {
  const _BuildConfigBar({required this.cart});

  final Cart? cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuildCompatibilityScreen(cart: cart),
              ),
            );
          },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Xây dựng cấu hình'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1F67E2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.totalItems} sản phẩm',
                      style: const TextStyle(
                        color: Color(0xFF6B7893),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      formatCurrency(cart.totalAmount),
                      style: const TextStyle(
                        color: Color(0xFF1F67E2),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1F67E2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Thanh toán',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuildCompatibilityScreen(cart: cart),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Xây dựng cấu hình'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F67E2),
                side: const BorderSide(color: Color(0xFFB9D9FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
