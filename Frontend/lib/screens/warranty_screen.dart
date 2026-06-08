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

class _WarrantyScreenState extends State<WarrantyScreen> {
  bool _isLoading = true;
  String? _error;
  List<PurchasedProduct> _purchasedProducts = const [];
  List<OrderSummary> _orders = const [];
  List<OrderDetail> _orderDetails = const [];
  List<WarrantyClaim> _claims = const [];
  String _selectedTab = 'products';

  static const _tabs = [
    _ProductTab('products', 'Sản phẩm'),
    _ProductTab('claims', 'Yêu cầu bảo hành'),
    _ProductTab('valid', 'Còn hạn'),
    _ProductTab('expired', 'Hết hạn'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
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
      final purchasedProducts = await _loadPurchasedProducts();
      final orderResponse = await ApiService.getMyOrders();
      final claimResponse = await ApiService.getWarrantyClaimsByAccount(
        accountId,
      );
      if (!mounted) return;

      final orders = orderResponse.data ?? const <OrderSummary>[];
      final productOrders = orders
          .where((order) => order.status != 'cancelled')
          .toList();
      final orderDetails = <OrderDetail>[];
      for (final order in productOrders) {
        final detail = await _loadOrderDetail(order);
        if (detail != null) {
          orderDetails.add(detail);
        }
      }
      if (!mounted) return;

      setState(() {
        _purchasedProducts = purchasedProducts;
        _orders = orders;
        _orderDetails = orderDetails;
        _claims = _sortClaims(claimResponse.data ?? const <WarrantyClaim>[]);
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

  Future<OrderDetail?> _loadOrderDetail(OrderSummary order) async {
    try {
      final response = await ApiService.getOrderDetail(order.orderId);
      return response.data;
    } catch (_) {
      return null;
    }
  }

  List<_OwnedProduct> get _products {
    if (_purchasedProducts.isNotEmpty) {
      final products = _purchasedProducts.map(_fromPurchasedProduct).toList();
      products.sort(_compareProducts);
      return products;
    }

    final products = <_OwnedProduct>[];
    final detailsById = {
      for (final detail in _orderDetails) detail.orderId: detail,
    };

    for (final order in _orders) {
      if (order.status == 'cancelled') continue;

      final items = order.items.isNotEmpty
          ? order.items
          : detailsById[order.orderId]?.items ?? const <OrderItem>[];

      for (final item in items) {
        final serials = item.serials.isNotEmpty
            ? item.serials
            : <OrderSerial>[OrderSerial()];
        for (final serial in serials) {
          products.add(
            _OwnedProduct(
              productName: item.productName ?? 'Sản phẩm',
              sku: item.sku,
              imageUrl: item.mainImageUrl,
              serialCode: serial.serialCode,
              orderCode: order.orderCode,
              createdOn: order.createdOn,
              warrantyEndDate: order.warrantyEndDate,
              hasWarranty: order.status == 'completed' &&
                  order.warrantyRemainingText != null,
              isWarrantyExpired: order.isWarrantyExpired == true,
              warrantyRemainingText: order.warrantyRemainingText,
            ),
          );
        }
      }
    }

    products.sort(_compareProducts);
    return products;
  }

  Future<List<PurchasedProduct>> _loadPurchasedProducts() async {
    try {
      final response = await ApiService.getPurchasedProducts();
      return response.data ?? const <PurchasedProduct>[];
    } catch (_) {
      return const <PurchasedProduct>[];
    }
  }

  List<_OwnedProduct> get _visibleProducts {
    final products = _products;
    if (_selectedTab == 'valid') {
      return products
          .where((product) => product.hasWarranty && !product.isWarrantyExpired)
          .toList();
    }
    if (_selectedTab == 'expired') {
      return products
          .where((product) => product.hasWarranty && product.isWarrantyExpired)
          .toList();
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Sản phẩm của tôi',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _TabRow(
          tabs: _tabs,
          selectedTab: _selectedTab,
          onTabChanged: (value) => setState(() => _selectedTab = value),
        ),
        const SizedBox(height: 14),
        if (_selectedTab == 'claims')
          _ClaimList(claims: _claims)
        else
          _ProductList(products: _visibleProducts),
      ],
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<_ProductTab> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = selectedTab == tab.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(tab.label),
              onSelected: (_) => onTabChanged(tab.value),
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
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products});

  final List<_OwnedProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Center(child: Text('Không có sản phẩm phù hợp')),
      );
    }

    return Column(
      children: products
          .map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OwnedProductCard(product: product),
            ),
          )
          .toList(),
    );
  }
}

class _ClaimList extends StatelessWidget {
  const _ClaimList({required this.claims});

  final List<WarrantyClaim> claims;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Center(child: Text('Không có yêu cầu bảo hành')),
      );
    }

    return Column(
      children: claims
          .map(
            (claim) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WarrantyClaimCard(claim: claim),
            ),
          )
          .toList(),
    );
  }
}

class _OwnedProductCard extends StatelessWidget {
  const _OwnedProductCard({required this.product});

  final _OwnedProduct product;

  @override
  Widget build(BuildContext context) {
    final expired = product.isWarrantyExpired;
    final color = !product.hasWarranty
        ? const Color(0xFF6B7893)
        : expired
        ? Colors.red.shade600
        : const Color(0xFF10B981);
    final warrantyText = !product.hasWarranty
        ? 'Bảo hành: Chưa kích hoạt'
        : expired
        ? 'Bảo hành: Hết hạn'
        : 'Bảo hành: ${product.warrantyRemainingText ?? 'Còn hạn'}';

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
          _ProductImage(url: product.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF14213D),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                if (product.sku?.isNotEmpty == true)
                  Text(
                    'SKU: ${product.sku}',
                    style: const TextStyle(
                      color: Color(0xFF6B7893),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (product.serialCode?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Serial: ${product.serialCode}',
                    style: const TextStyle(
                      color: Color(0xFF42526E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      !product.hasWarranty
                          ? Icons.hourglass_empty_rounded
                          : expired
                          ? Icons.gpp_bad_rounded
                          : Icons.verified_user_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warrantyText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (product.warrantyEndDate?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Hạn bảo hành: ${product.warrantyEndDate}',
                    style: const TextStyle(
                      color: Color(0xFF91A0B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  'Đơn hàng: ${product.orderCode}',
                  style: const TextStyle(
                    color: Color(0xFF91A0B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 78,
              height: 78,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.memory_rounded,
        size: 32,
        color: Color(0xFF1F67E2),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
            style: const TextStyle(color: Color(0xFF42526E), height: 1.4),
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

class _OwnedProduct {
  const _OwnedProduct({
    required this.productName,
    required this.orderCode,
    required this.hasWarranty,
    required this.isWarrantyExpired,
    this.sku,
    this.imageUrl,
    this.serialCode,
    this.createdOn,
    this.warrantyEndDate,
    this.warrantyRemainingText,
  });

  final String productName;
  final String orderCode;
  final bool hasWarranty;
  final bool isWarrantyExpired;
  final String? sku;
  final String? imageUrl;
  final String? serialCode;
  final String? createdOn;
  final String? warrantyEndDate;
  final String? warrantyRemainingText;
}

_OwnedProduct _fromPurchasedProduct(PurchasedProduct product) {
  final hasWarranty =
      product.orderStatus == 'completed' && product.warrantyRemainingText != null;
  return _OwnedProduct(
    productName: product.productName ?? 'Sản phẩm',
    sku: product.sku,
    imageUrl: product.mainImageUrl,
    serialCode: product.serialCode,
    orderCode: product.orderCode ?? '-',
    createdOn: product.createdOn,
    warrantyEndDate: product.warrantyEndDate,
    hasWarranty: hasWarranty,
    isWarrantyExpired: product.isWarrantyExpired,
    warrantyRemainingText: product.warrantyRemainingText,
  );
}

int _compareProducts(_OwnedProduct a, _OwnedProduct b) {
  final aValid = a.hasWarranty && !a.isWarrantyExpired;
  final bValid = b.hasWarranty && !b.isWarrantyExpired;
  if (aValid != bValid) {
    return aValid ? -1 : 1;
  }
  return (b.createdOn ?? '').compareTo(a.createdOn ?? '');
}

class _ProductTab {
  final String value;
  final String label;

  const _ProductTab(this.value, this.label);
}

List<WarrantyClaim> _sortClaims(List<WarrantyClaim> claims) {
  final sorted = [...claims];
  sorted.sort((a, b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted;
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

String _two(int value) => value.toString().padLeft(2, '0');
