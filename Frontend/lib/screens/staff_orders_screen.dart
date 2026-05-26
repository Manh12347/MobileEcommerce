import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'order_detail_screen.dart';

class StaffOrdersScreen extends StatefulWidget {
  const StaffOrdersScreen({super.key});

  @override
  State<StaffOrdersScreen> createState() => _StaffOrdersScreenState();
}

class _StaffOrdersScreenState extends State<StaffOrdersScreen> {
  static const _filters = [
    ('', 'Tất cả'),
    ('pending', 'Chờ xử lý'),
    ('shipping', 'Đang giao'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã hủy'),
  ];

  String _statusFilter = '';
  bool _isLoading = true;
  String? _error;
  List<OrderSummary> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getStaffOrders(
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _orders = response.success ? (response.data ?? const []) : const [];
        _error = response.success
            ? null
            : (response.message.isNotEmpty ? response.message : 'Lỗi');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(OrderSummary order, String newStatus) async {
    try {
      final response = await ApiService.updateStaffOrderStatus(
        orderId: order.orderId,
        status: newStatus,
      );
      if (!mounted) return;
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật → ${orderStatusLabel(newStatus)}')),
        );
        _load();
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
    }
  }

  void _showStatusActions(OrderSummary order) {
    final options = <String>[];
    if (order.status == 'pending') {
      options.addAll(['shipping', 'cancelled']);
    } else if (order.status == 'shipping') {
      options.add('completed');
    }

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đổi trạng thái đơn này')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Cập nhật ${order.orderCode}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ...options.map(
              (status) => ListTile(
                leading: Icon(
                  status == 'cancelled' ? Icons.cancel_outlined : Icons.check_circle_outline,
                  color: orderStatusColor(status),
                ),
                title: Text(orderStatusLabel(status)),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(order, status);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Xử lý đơn hàng (Staff)',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = _statusFilter == filter.$1;
                return FilterChip(
                  label: Text(filter.$2),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter = filter.$1);
                    _load();
                  },
                  selectedColor: const Color(0xFF1F67E2).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF1F67E2),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF1F67E2),
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 80, child: Center(child: Text(_error!)))],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Không có đơn hàng')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(
              order.orderCode,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${orderStatusLabel(order.status)} • ${formatCurrency(order.totalPrice)}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'detail') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: order.orderId),
                    ),
                  );
                } else if (value == 'status') {
                  _showStatusActions(order);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'detail', child: Text('Chi tiết')),
                PopupMenuItem(value: 'status', child: Text('Cập nhật trạng thái')),
              ],
            ),
          ),
        );
      },
    );
  }
}
