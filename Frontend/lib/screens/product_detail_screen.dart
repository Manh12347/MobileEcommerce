import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.summary,
    this.initialDetail,
  });

  final ProductItemSummary summary;
  final ProductItemDetail? initialDetail;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductItemDetail?> _detailFuture;
  int _quantity = 1;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  int _maxStock(ProductItemDetail? detail) {
    return detail?.stockQuantity ?? widget.summary.stockQuantity ?? 0;
  }

  bool _canPurchase(ProductItemDetail? detail) {
    final status = detail?.status ?? widget.summary.status;
    return status?.toLowerCase() == 'active' && _maxStock(detail) > 0;
  }

  Future<void> _addToCart(ProductItemDetail? detail) async {
    final productItemId = detail?.id ?? widget.summary.id;
    if (productItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được sản phẩm')),
      );
      return;
    }

    final stock = _maxStock(detail);
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm đã hết hàng')),
      );
      return;
    }

    if (_quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chỉ còn $stock sản phẩm trong kho')),
      );
      return;
    }

    setState(() => _isAdding = true);
    final ok = await context.read<CartProvider>().addToCart(
          productItemId: productItemId,
          quantity: _quantity,
        );
    if (!mounted) return;
    setState(() => _isAdding = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $_quantity sản phẩm vào giỏ'),
          action: SnackBarAction(
            label: 'Xem giỏ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
    } else {
      final msg = context.read<CartProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : 'Không thêm được vào giỏ')),
      );
    }
  }

  Future<ProductItemDetail?> _loadDetail() async {
    if (widget.initialDetail != null) {
      return widget.initialDetail;
    }

    final id = widget.summary.id;
    if (id == null) {
      return null;
    }

    try {
      final response = await ApiService.getProductItemDetail(id);
      return response.success ? response.data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chi tiết sản phẩm',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF1F67E2),
        child: FutureBuilder<ProductItemDetail?>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1F67E2),
                ),
              );
            }

            final detail = snapshot.data;
            final stock = _maxStock(detail);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _ProductHeroCard(
                  summary: widget.summary,
                  detail: detail,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Phiên bản (SKU)',
                  child: _VariantSelector(
                    summary: widget.summary,
                    detail: detail,
                    quantity: _quantity,
                    maxStock: stock,
                    onQuantityChanged: (q) => setState(() => _quantity = q),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Thông tin chính',
                  child: Column(
                    children: [
                      _InfoRow(label: 'SKU', value: detail?.sku ?? '-'),
                      _InfoRow(
                        label: 'Danh mục',
                        value: widget.summary.category?.name ?? '-',
                      ),
                      _InfoRow(
                        label: 'Thương hiệu',
                        value: widget.summary.brand?.name ?? '-',
                      ),
                      _InfoRow(
                        label: 'Trạng thái',
                        value: _statusLabel(
                          detail?.status ?? widget.summary.status,
                        ),
                      ),
                      _InfoRow(
                        label: 'Tồn kho',
                        value: detail?.stockQuantity != null
                            ? '${detail!.stockQuantity}'
                            : '-',
                      ),
                      _InfoRow(
                        label: 'Sản phẩm gốc',
                        value: detail?.productName ?? widget.summary.name,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Mô tả sản phẩm',
                  child: Text(
                    detail?.description?.isNotEmpty == true
                        ? detail!.description!
                        : 'Chưa có mô tả chi tiết cho sản phẩm này.',
                    style: const TextStyle(
                      color: Color(0xFF42506A),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Giá bán',
                  child: _PriceBlock(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Thông số kỹ thuật',
                  child: _SpecificationsGrid(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Serial',
                  child: _SerialList(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Dữ liệu hệ thống',
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Product item ID',
                        value: detail?.id?.toString() ?? '-',
                      ),
                      _InfoRow(
                        label: 'Created at',
                        value: _formatDate(detail?.createdAt),
                      ),
                      _InfoRow(
                        label: 'Updated at',
                        value: _formatDate(detail?.updatedAt),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<ProductItemDetail?>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final canBuy = _canPurchase(detail);
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: !canBuy || _isAdding ? null : () => _addToCart(detail),
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart_outlined),
                label: Text(
                  canBuy ? 'Thêm vào giỏ ($_quantity)' : 'Hết hàng / Ngừng bán',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1F67E2),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.summary,
    required this.detail,
    required this.quantity,
    required this.maxStock,
    required this.onQuantityChanged,
  });

  final ProductItemSummary summary;
  final ProductItemDetail? detail;
  final int quantity;
  final int maxStock;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final specs = detail?.specifications ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB9D9FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 18, color: Color(0xFF1F67E2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SKU: ${detail?.sku ?? summary.sku ?? '-'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F67E2),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Thông số phiên bản',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF42506A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs.entries
                .map(
                  (e) => Chip(
                    label: Text('${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFFF0F5FC),
                    side: const BorderSide(color: Color(0xFFE3EAF5)),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Số lượng',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF14213D),
              ),
            ),
            const Spacer(),
            _QtyBtn(
              icon: Icons.remove,
              enabled: quantity > 1,
              onTap: () => onQuantityChanged(quantity - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _QtyBtn(
              icon: Icons.add,
              enabled: maxStock > 0 && quantity < maxStock,
              onTap: () => onQuantityChanged(quantity + 1),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          maxStock > 0 ? 'Còn $maxStock sản phẩm trong kho' : 'Hết hàng',
          style: TextStyle(
            fontSize: 12,
            color: maxStock > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFFF0F5FC) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? const Color(0xFF1F67E2) : const Color(0xFFB8C4DA),
          ),
        ),
      ),
    );
  }
}

class _ProductHeroCard extends StatelessWidget {
  const _ProductHeroCard({required this.summary, required this.detail});

  final ProductItemSummary summary;
  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail?.mainImageUrl;
    final price = detail?.salePrice ?? detail?.price;
    final originalPrice = detail?.hasSalePrice == true ? detail?.price : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10284F), Color(0xFF1F67E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F67E2).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.category?.name ?? 'Sản phẩm',
                        style: const TextStyle(
                          color: Color(0xFFDCEBFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.brand?.name ?? '',
                        style: const TextStyle(
                          color: Color(0xFFDCEBFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 104,
                  width: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _HeroImage(url: imageUrl),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Badge(
                  text: _statusLabel(detail?.status ?? summary.status),
                  backgroundColor: const Color(0xFF0C8C71),
                ),
                const SizedBox(width: 10),
                if (detail?.stockQuantity != null)
                  _Badge(
                    text: 'Tồn kho: ${detail!.stockQuantity}',
                    backgroundColor: const Color(0xFF20365D),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (price != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(price),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (originalPrice != null) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _formatCurrency(originalPrice),
                        style: const TextStyle(
                          color: Color(0xFFBED3FF),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              const Text(
                'Giá đang cập nhật',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(
          Icons.memory_rounded,
          size: 54,
          color: Colors.white,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.memory_rounded,
              size: 54,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF14213D),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7893),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17243D),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return const Text(
        'Chưa có dữ liệu giá chi tiết.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final currentPrice = detail!.salePrice ?? detail!.price;
    final originalPrice = detail!.hasSalePrice ? detail!.price : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentPrice != null)
          Text(
            _formatCurrency(currentPrice),
            style: const TextStyle(
              color: Color(0xFF1F67E2),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (originalPrice != null) ...[
          const SizedBox(height: 4),
          Text(
            _formatCurrency(originalPrice),
            style: const TextStyle(
              color: Color(0xFF91A0B8),
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _InfoRow(
          label: 'Sale price',
          value: detail!.salePrice != null
              ? _formatCurrency(detail!.salePrice)
              : '-',
        ),
        _InfoRow(
          label: 'Price',
          value: detail!.price != null ? _formatCurrency(detail!.price) : '-',
        ),
      ],
    );
  }
}

class _SpecificationsGrid extends StatelessWidget {
  const _SpecificationsGrid({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final specs = detail?.specifications ?? const {};
    if (specs.isEmpty) {
      return const Text(
        'Chưa có thông số kỹ thuật.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final entries = specs.entries.toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries
          .map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Color(0xFF6B7893),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      color: Color(0xFF17243D),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SerialList extends StatelessWidget {
  const _SerialList({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final serials = detail?.serials ?? const <ProductSerial>[];
    if (serials.isEmpty) {
      return const Text(
        'Chưa có serial nào được nhập.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      children: serials
          .map(
            (serial) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF1F67E2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serial.serialCode ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF17243D),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serial.status ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF6B7893),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.backgroundColor});

  final String text;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'active':
      return 'Hoạt động';
    case 'disable':
      return 'Ngừng bán';
    case 'discontinued':
      return 'Ngưng bán';
    default:
      return status?.isNotEmpty == true ? status! : 'Không xác định';
  }
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return '-';
  }

  return '${dateTime.year.toString().padLeft(4, '0')}-'
      '${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

String _formatCurrency(num? value) {
  if (value == null) {
    return '0đ';
  }

  final rounded = value.round();
  final reversed = rounded.toString().split('').reversed.toList();
  final buffer = StringBuffer();

  for (var i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(reversed[i]);
  }

  return '${buffer.toString().split('').reversed.join()}đ';
}