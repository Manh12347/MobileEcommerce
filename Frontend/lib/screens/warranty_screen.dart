import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/warranty.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';

class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key});

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<_WarrantyProduct> _warrantyProducts = const [];
  List<WarrantyClaim> _claims = const [];
  String _productFilter = 'active';
  String _historyFilter = 'all';

  static const _productFilters = [
    _WarrantyFilter('active', 'Còn hiệu lực'),
    _WarrantyFilter('expired', 'Hết hiệu lực'),
  ];

  static const _filters = [
    _WarrantyFilter('all', 'Tất cả'),
    _WarrantyFilter('completed', 'Đã xong'),
    _WarrantyFilter('processing', 'Đang xử lý'),
    _WarrantyFilter('cancelled', 'Bị hủy'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final accountId = context.read<LoginProvider>().loginResponse?.accountId;
    if (accountId == null) {
      setState(() {
        _error = 'Không tìm thấy tài khoản đăng nhập';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final warrantyProducts = await _loadWarrantyProducts();
      final claims = await _loadClaims(accountId);
      if (!mounted) return;
      setState(() {
        _warrantyProducts = warrantyProducts;
        _claims = claims;
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

  Future<List<WarrantyClaim>> _loadClaims(int accountId) async {
    final response = await ApiService.getWarrantyClaimsByAccount(accountId);
    final claims = response.data ?? const <WarrantyClaim>[];
    final sorted = [...claims];
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  Future<List<_WarrantyProduct>> _loadWarrantyProducts() async {
    final ordersResponse = await ApiService.getMyOrders();
    final orders = ordersResponse.data ?? const <OrderSummary>[];
    final products = <_WarrantyProduct>[];
    final seenSerialIds = <int>{};
    final now = DateTime.now();

    for (final order in orders) {
      if (order.orderId == 0 || order.status == 'cancelled') continue;
      final detailResponse = await ApiService.getOrderDetail(order.orderId);
      final detail = detailResponse.data;
      if (detail == null) continue;

      for (final item in detail.items) {
        for (final serial in item.serials) {
          final serialId = serial.serialId;
          if (serialId == null || seenSerialIds.contains(serialId)) continue;
          seenSerialIds.add(serialId);

          try {
            final warrantyResponse = await ApiService.getWarrantyBySerial(serialId);
            final warranty = warrantyResponse.data;
            final remaining = warranty?.remainingDays(now);
            if (warranty == null || remaining == null) {
              continue;
            }
            products.add(
              _WarrantyProduct(
                productName: item.productName ?? 'Sản phẩm',
                sku: item.sku,
                serialCode: serial.serialCode ?? warranty.serialCode,
                warranty: warranty,
              ),
            );
          } catch (_) {
            // Some serials may not have warranty records yet.
          }
        }
      }
    }

    products.sort((a, b) {
      final aActive = a.isActive(now);
      final bActive = b.isActive(now);
      if (aActive != bActive) return aActive ? -1 : 1;
      final aDays = a.warranty.remainingDays(now) ?? -999999;
      final bDays = b.warranty.remainingDays(now) ?? -999999;
      return aDays.compareTo(bDays);
    });
    return products;
  }

  List<_WarrantyProduct> get _filteredWarrantyProducts {
    final now = DateTime.now();
    return _warrantyProducts.where((product) {
      final active = product.isActive(now);
      return _productFilter == 'active' ? active : !active;
    }).toList();
  }

  List<WarrantyClaim> get _filteredClaims {
    if (_historyFilter == 'all') return _claims;
    return _claims
        .where((claim) => _normalizeStatus(claim.status) == _historyFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Bảo hành',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1F67E2),
          unselectedLabelColor: const Color(0xFF6B7893),
          indicatorColor: const Color(0xFF1F67E2),
          tabs: const [
            Tab(text: 'Sản phẩm'),
            Tab(text: 'Lịch sử'),
          ],
        ),
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
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7893)),
              ),
            ),
          ),
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _ValidWarrantyTab(
          products: _filteredWarrantyProducts,
          filters: _productFilters,
          selectedFilter: _productFilter,
          onFilterChanged: (value) => setState(() => _productFilter = value),
        ),
        _HistoryTab(
          claims: _filteredClaims,
          filters: _filters,
          selectedFilter: _historyFilter,
          onFilterChanged: (value) => setState(() => _historyFilter = value),
        ),
      ],
    );
  }
}

class _ValidWarrantyTab extends StatelessWidget {
  const _ValidWarrantyTab({
    required this.products,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<_WarrantyProduct> products;
  final List<_WarrantyFilter> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final selected = selectedFilter == filter.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(filter.label),
                  onSelected: (_) => onFilterChanged(filter.value),
                  selectedColor: const Color(0xFFE8F4FF),
                  checkmarkColor: const Color(0xFF1F67E2),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF1F67E2)
                        : const Color(0xFF6B7893),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFB9D8FF)
                        : const Color(0xFFE3EAF5),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Center(
              child: Text(
                selectedFilter == 'active'
                    ? 'Không có sản phẩm còn hiệu lực'
                    : 'Không có sản phẩm hết hiệu lực',
              ),
            ),
          )
        else
          ...products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ValidWarrantyCard(item: product),
            ),
          ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.claims,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<WarrantyClaim> claims;
  final List<_WarrantyFilter> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final selected = selectedFilter == filter.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(filter.label),
                  onSelected: (_) => onFilterChanged(filter.value),
                  selectedColor: const Color(0xFFE8F4FF),
                  checkmarkColor: const Color(0xFF1F67E2),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF1F67E2)
                        : const Color(0xFF6B7893),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFB9D8FF)
                        : const Color(0xFFE3EAF5),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (claims.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 90),
            child: Center(child: Text('Không có lịch sử bảo hành')),
          )
        else
          ...claims.map(
            (claim) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WarrantyClaimCard(claim: claim),
            ),
          ),
      ],
    );
  }
}

class _ValidWarrantyCard extends StatelessWidget {
  const _ValidWarrantyCard({required this.item});

  final _WarrantyProduct item;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = item.warranty.remainingDays(now);
    final active = item.isActive(now);
    final urgent = active && remaining != null && remaining <= 30;
    final labelColor = active
        ? (urgent ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
        : const Color(0xFFEF4444);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF1F67E2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF14213D),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.serialCode ?? 'Chưa có serial',
                      style: const TextStyle(
                        color: Color(0xFF6B7893),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.timer_outlined,
                text: _warrantyRemainingText(remaining),
                color: labelColor,
              ),
              _InfoPill(
                icon: Icons.event_available_outlined,
                text: 'HSD ${_formatDate(item.warranty.endDate)}',
                color: const Color(0xFF1F67E2),
              ),
              if (item.sku != null && item.sku!.isNotEmpty)
                _InfoPill(
                  icon: Icons.qr_code_2_outlined,
                  text: item.sku!,
                  color: const Color(0xFF6B7893),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarrantyClaimCard extends StatelessWidget {
  const _WarrantyClaimCard({required this.claim});

  final WarrantyClaim claim;

  @override
  Widget build(BuildContext context) {
    final status = _normalizeStatus(claim.status);
    final statusColor = _statusColor(status);

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
                  claim.productName ?? 'Sản phẩm bảo hành',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF14213D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            claim.serialCode ?? claim.serialSeries ?? 'Chưa có serial',
            style: const TextStyle(color: Color(0xFF6B7893), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            claim.issueDescription?.isNotEmpty == true
                ? claim.issueDescription!
                : 'Chưa có mô tả',
            style: const TextStyle(
              color: Color(0xFF42526E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 16,
                color: Color(0xFF91A0B8),
              ),
              const SizedBox(width: 6),
              Text(
                'Ngày tạo: ${_formatDateTime(claim.createdAt)}',
                style: const TextStyle(
                  color: Color(0xFF91A0B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarrantyProduct {
  final String productName;
  final String? sku;
  final String? serialCode;
  final Warranty warranty;

  _WarrantyProduct({
    required this.productName,
    this.sku,
    this.serialCode,
    required this.warranty,
  });

  bool isActive(DateTime now) {
    final remaining = warranty.remainingDays(now);
    return warranty.isActive && remaining != null && remaining >= 0;
  }
}

class _WarrantyFilter {
  final String value;
  final String label;

  const _WarrantyFilter(this.value, this.label);
}

String _normalizeStatus(String? status) {
  final value = status?.toLowerCase().trim();
  switch (value) {
    case 'completed':
      return 'completed';
    case 'cancelled':
    case 'canceled':
    case 'rejected':
      return 'cancelled';
    case 'pending':
    case 'approved':
    case 'processing':
      return 'processing';
    default:
      return value?.isNotEmpty == true ? value! : 'processing';
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'completed':
      return 'Đã xong';
    case 'cancelled':
      return 'Bị hủy';
    case 'processing':
      return 'Đang xử lý';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return const Color(0xFF10B981);
    case 'cancelled':
      return const Color(0xFFEF4444);
    case 'processing':
      return const Color(0xFF1F67E2);
    default:
      return const Color(0xFF6B7893);
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '-';
  return '${_two(value.day)}/${_two(value.month)}/${value.year}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  return '${_formatDate(value)} ${_two(value.hour)}:${_two(value.minute)}';
}

String _warrantyRemainingText(int? remaining) {
  if (remaining == null) return 'Không rõ hạn';
  if (remaining < 0) return 'Hết hiệu lực';
  if (remaining == 0) return 'Hết hạn hôm nay';
  return 'Còn $remaining ngày';
}

String _two(int value) => value.toString().padLeft(2, '0');
