import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentMethod = 'COD';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (address.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ và số điện thoại')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.checkout(
        CreateOrderRequest(
          shippingAddress: address,
          phone: phone,
          paymentMethod: _paymentMethod,
        ),
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        await context.read<CartProvider>().loadCart(silent: true);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              orderId: response.data!.orderId,
              initialOrder: response.data,
            ),
          ),
          (route) => route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đặt hàng thành công — ${response.data!.orderCode}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isNotEmpty ? response.message : 'Đặt hàng thất bại',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>().cart;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Thanh toán',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Địa chỉ giao hàng',
            child: Column(
              children: [
                TextField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: _inputDecoration('Địa chỉ đầy đủ'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Số điện thoại'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Phương thức thanh toán',
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'COD',
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  title: const Text('Thanh toán khi nhận hàng (COD)'),
                  activeColor: const Color(0xFF1F67E2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tóm tắt đơn hàng',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart?.totalItems ?? 0} sản phẩm',
                  style: const TextStyle(color: Color(0xFF6B7893)),
                ),
                const SizedBox(height: 8),
                if (cart != null && cart.promotionSavings > 0)
                  Text(
                    'Giảm giá khuyến mãi: -${formatCurrency(cart.promotionSavings)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Tổng thanh toán: ${formatCurrency(cart?.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F67E2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F67E2),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Đặt hàng',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF14213D),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
