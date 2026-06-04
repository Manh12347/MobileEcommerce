import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';
import '../utils/app_globals.dart';
import '../utils/format_utils.dart';
import '../widgets/notification_bell.dart';
import 'order_detail_screen.dart';
import 'order_track_screen.dart';
import 'staff_orders_screen.dart';
import 'warranty_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedStatus = 'completed';

  bool _isLoading = true;
  String? _error;
  List<OrderSummary> _allOrders = const [];
  List<OrderSummary> _filteredOrders = const [];

  static const _statusFilters = [
    ('completed', 'Hoàn thành'),
    ('warranty_expired', 'Hết hạn bảo hành'),
    ('pending', 'Chờ xử lý'),
    ('shipping', 'Đang giao'),
    ('cancelled', 'Đã hủy'),
  ];

  @override
  void initState() {
    super.initState();
    refreshOrdersNotifier.addListener(_handleRefreshRequest);
    _load();
  }

  @override
  void dispose() {
    refreshOrdersNotifier.removeListener(_handleRefreshRequest);
    _searchController.dispose();
    super.dispose();
  }

  void _handleRefreshRequest() {
    if (mounted) {
      _load();
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        bool matchesStatus;
        if (_selectedStatus == 'completed') {
          matchesStatus =
              order.status == 'completed' && order.isWarrantyExpired != true;
        } else if (_selectedStatus == 'warranty_expired') {
          matchesStatus =
              order.status == 'completed' && order.isWarrantyExpired == true;
        } else {
          matchesStatus = order.status == _selectedStatus;
        }

        if (_query.isEmpty) return matchesStatus;
        return matchesStatus &&
            (order.orderCode.toLowerCase().contains(_query) ||
                order.paymentStatus?.toLowerCase().contains(_query) == true);
      }).toList();

      // Sort by valid warranty first, then latest buy (createdOn DESC)
      _filteredOrders.sort((a, b) {
        final aExpired = a.isWarrantyExpired == true;
        final bExpired = b.isWarrantyExpired == true;
        if (aExpired != bExpired) {
          return aExpired ? 1 : -1;
        }

        final aDate = a.createdOn ?? '';
        final bDate = b.createdOn ?? '';
        return bDate.compareTo(aDate);
      });
    });
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
          _allOrders = response.data ?? const [];
          _applyFilter();
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
          const NotificationBell(),
          IconButton(
            tooltip: 'Lịch sử bảo hành',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WarrantyScreen()),
              );
            },
            icon: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF1F67E2),
            ),
          ),
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
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2EAF5)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    setState(() => _query = v.trim().toLowerCase());
                    _applyFilter();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Tìm mã đơn, trạng thái...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            // Status filter chips
            SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (status, label) = _statusFilters[index];
                  final selected = _selectedStatus == status;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(label),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF17315D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: const Color(0xFF1F67E2),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF1F67E2)
                          : const Color(0xFFD8E3F3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      setState(() => _selectedStatus = status);
                      _applyFilter();
                    },
                  );
                },
              ),
            ),
            // Order count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredOrders.length} đơn hàng',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7893),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
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

    if (_filteredOrders.isEmpty) {
      return const Center(
        child: Text(
          'Không có đơn hàng phù hợp',
          style: TextStyle(
            color: Color(0xFF5F6B82),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
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
              if (order.paymentStatus != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Thanh toán: ${paymentStatusLabel(order.paymentStatus)}',
                  style: const TextStyle(
                    color: Color(0xFF6B7893),
                    fontSize: 12,
                  ),
                ),
              ],
              if (order.status == 'completed' &&
                  order.warrantyRemainingText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      order.isWarrantyExpired == true
                          ? Icons.gpp_bad_rounded
                          : Icons.verified_user_rounded,
                      size: 16,
                      color: order.isWarrantyExpired == true
                          ? Colors.red.shade600
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.isWarrantyExpired == true
                          ? 'Bảo hành: Hết hạn'
                          : 'Bảo hành: ${order.warrantyRemainingText}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: order.isWarrantyExpired == true
                            ? Colors.red.shade600
                            : const Color(0xFF10B981),
                      ),
                    ),
                    if (order.warrantyEndDate != null &&
                        order.isWarrantyExpired != true) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${order.warrantyEndDate})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (order.createdOn != null) ...[
                const SizedBox(height: 4),
                Text(
                  formatOrderDate(order.createdOn),
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
