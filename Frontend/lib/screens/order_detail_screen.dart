import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'order_track_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final int orderId;
  final OrderDetail? initialOrder;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetail? _order;
  bool _isLoading = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    if (_order == null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getOrderDetail(widget.orderId);
      if (!mounted) return;
      if (response.success) {
        setState(() => _order = response.data);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: const Text(
          'Bạn có chắc muốn hủy đơn? Tồn kho sẽ được hoàn lại khi đơn còn trạng thái chờ xử lý.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final response = await ApiService.cancelOrder(widget.orderId);
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() => _order = response.data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy đơn hàng')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Chi tiết đơn hàng',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (order != null)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackScreen(orderCode: order.orderCode),
                  ),
                );
              },
              icon: const Icon(Icons.timeline_outlined),
              tooltip: 'Theo dõi',
            ),
        ],
      ),
      body: _isLoading && order == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F67E2)))
          : order == null
              ? const Center(child: Text('Không tải được đơn hàng'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoCard(order: order),
                      const SizedBox(height: 16),
                      _SectionTitle('Sản phẩm'),
                      ...order.items.map((item) => _OrderItemTile(item: item)),
                      if (order.status == 'pending') ...[
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: _isCancelling ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Hủy đơn hàng'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14213D),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  orderStatusLabel(order.status),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _row('Trạng thái thanh toán', order.paymentStatus ?? '-'),
          _row('Phương thức', order.paymentMethod ?? '-'),
          _row('Địa chỉ giao', order.shippingAddress ?? '-'),
          _row('Điện thoại', order.phone ?? '-'),
          _row('Tổng tiền', formatCurrency(order.totalPrice)),
          if (order.createdOn != null) _row('Ngày tạo', order.createdOn!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7893), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF14213D),
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName ?? 'Sản phẩm',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('SKU: ${item.sku ?? '-'} • x${item.quantity}',
              style: const TextStyle(color: Color(0xFF6B7893), fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            formatCurrency(item.lineTotal ?? item.price),
            style: const TextStyle(
              color: Color(0xFF1F67E2),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.serials.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Serial number:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF42506A),
              ),
            ),
            ...item.serials.map(
              (s) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${s.serialCode ?? '-'} (${s.status ?? ''})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7893)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
