import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'order_detail_screen.dart';
import 'order_track_screen.dart';
import 'staff_orders_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
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
      final response = await ApiService.getMyOrders();
      if (!mounted) return;
      if (response.success) {
        setState(() {
          _orders = response.data ?? const [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message.isNotEmpty
              ? response.message
              : 'Lỗi tải đơn';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<LoginProvider>().isStaff;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Đơn hàng của tôi',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (isStaff)
            IconButton(
              tooltip: 'Quản lý đơn (Staff)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffOrdersScreen()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1F67E2),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(child: Text(_error!)),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(child: Text('Chưa có đơn hàng nào')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _OrderCard(
          order: order,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: order.orderId),
              ),
            );
          },
          onTrack: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderTrackScreen(orderCode: order.orderCode),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onTrack,
  });

  final OrderSummary order;
  final VoidCallback onTap;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final statusColor = orderStatusColor(order.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14213D),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      orderStatusLabel(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.itemCount} sản phẩm • ${formatCurrency(order.totalPrice)}',
                style: const TextStyle(color: Color(0xFF6B7893), fontSize: 13),
              ),
              if (order.createdOn != null) ...[
                const SizedBox(height: 4),
                Text(
                  order.createdOn!,
                  style: const TextStyle(
                    color: Color(0xFF91A0B8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onTrack,
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: const Text('Theo dõi'),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Color(0xFF91A0B8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
