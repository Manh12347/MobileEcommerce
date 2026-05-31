import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../widgets/product_badge.dart';
import '../utils/app_globals.dart';

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
  late Future<List<ProductItemSummary>> _relatedProductsFuture;
  int _quantity = 1;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
    _relatedProductsFuture = _loadRelatedProducts();
  }

  int _maxStock(ProductItemDetail? detail) {
    return detail?.stockQuantity ?? widget.summary.stockQuantity ?? 0;
  }

  bool _canPurchase(ProductItemDetail? detail) {
    final status = detail?.status ?? widget.summary.status;
    return isActiveProductStatus(status) && _maxStock(detail) > 0;
  }

  Future<bool> _submitCartAction(
    ProductItemDetail? detail, {
    required bool navigateToCart,
  }) async {
    final productItemId = detail?.id ?? widget.summary.id;
    if (productItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được sản phẩm')),
      );
      return false;
    }

    final stock = _maxStock(detail);
    if (stock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sản phẩm đã hết hàng')));
      return false;
    }

    if (_quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chỉ còn $stock sản phẩm trong kho')),
      );
      return false;
    }

    setState(() => _isAdding = true);
    final ok = await context.read<CartProvider>().addToCart(
      productItemId: productItemId,
      quantity: _quantity,
    );
    if (!mounted) return false;
    setState(() => _isAdding = false);

    if (ok) {
      // Ensure the global cart state is reloaded so UI badges update in other screens.
      // ignore: unawaited_futures
      context.read<CartProvider>().loadCart(silent: true);
      
      if (navigateToCart) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm $_quantity sản phẩm vào giỏ')),
        );
        
        // Wait for snackbar to show, then navigate
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!mounted) return false;
        
        // Set the tab index BEFORE popping to ensure the listener catches it
        navigateToTabNotifier.value = 2;
        
        // Pop back to root - this will trigger the main shell to switch tabs
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm $_quantity sản phẩm vào giỏ')),
        );
      }
      return true;
    } else {
      final msg = context.read<CartProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'Không thêm được vào giỏ'),
        ),
      );
      return false;
    }
  }

  Future<void> _addToCart(ProductItemDetail? detail) async {
    await _submitCartAction(detail, navigateToCart: false);
  }

  Future<void> _buyNow(ProductItemDetail? detail) async {
    await _submitCartAction(detail, navigateToCart: true);
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

  Future<List<ProductItemSummary>> _loadRelatedProducts() async {
    try {
      final response = await ApiService.getProductItems(page: 1, size: 24);
      if (!response.success) {
        return const [];
      }

      final currentId = widget.summary.id;
      final categoryName = widget.summary.category?.name?.trim().toLowerCase();
      final brandName = widget.summary.brand?.name?.trim().toLowerCase();

      final items = response.data ?? const <ProductItemSummary>[];
      final related = items.where((item) {
        if (item.id == null || item.id == currentId) {
          return false;
        }
        if (!isActiveProductStatus(item.status)) {
          return false;
        }

        final itemCategory = item.category?.name?.trim().toLowerCase();
        final itemBrand = item.brand?.name?.trim().toLowerCase();
        final sameCategory =
            categoryName != null &&
            categoryName.isNotEmpty &&
            itemCategory == categoryName;
        final sameBrand =
            brandName != null && brandName.isNotEmpty && itemBrand == brandName;

        return sameCategory || sameBrand;
      }).toList();

      related.sort((left, right) {
        final leftSameCategory =
            left.category?.name?.trim().toLowerCase() == categoryName;
        final rightSameCategory =
            right.category?.name?.trim().toLowerCase() == categoryName;
        if (leftSameCategory != rightSameCategory) {
          return leftSameCategory ? -1 : 1;
        }

        final leftPrice = left.salePrice ?? left.price ?? 0;
        final rightPrice = right.salePrice ?? right.price ?? 0;
        return rightPrice.compareTo(leftPrice);
      });

      return related.take(6).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
      _relatedProductsFuture = _loadRelatedProducts();
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
                _ProductHeroCard(summary: widget.summary, detail: detail),
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
                        value: productStatusLabel(
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
                _RelatedProductsSection(
                  future: _relatedProductsFuture,
                  currentSummary: widget.summary,
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !canBuy || _isAdding
                          ? null
                          : () => _addToCart(detail),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(
                        canBuy ? 'Thêm vào giỏ' : 'Hết hàng / Ngừng bán',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F67E2),
                        side: const BorderSide(color: Color(0xFF1F67E2)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: !canBuy || _isAdding
                          ? null
                          : () => _buyNow(detail),
                      icon: _isAdding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.flash_on_outlined),
                      label: Text(
                        canBuy ? 'Mua ngay' : 'Hết hàng / Ngừng bán',
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VariantSelector extends StatefulWidget {
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
  State<_VariantSelector> createState() => _VariantSelectorState();
}

class _VariantSelectorState extends State<_VariantSelector> {
  int _selectedVersionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final specs = widget.detail?.specifications ?? const {};
    final specEntries = specs.entries.toList();
    final versionOptions = specEntries.isNotEmpty
        ? specEntries
        : [const MapEntry<String, dynamic>('Mặc định', 'Phiên bản hiện tại')];

    if (_selectedVersionIndex >= versionOptions.length) {
      _selectedVersionIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn phiên bản',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF42506A),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(versionOptions.length, (index) {
            final entry = versionOptions[index];
            final selected = index == _selectedVersionIndex;
            final label = _specValueText(entry.value);
            final subtitle = entry.key;

            return SizedBox(
              width: 140,
              child: _VersionCard(
                label: label,
                subtitle: subtitle == label ? null : subtitle,
                selected: selected,
                onTap: () => setState(() => _selectedVersionIndex = index),
              ),
            );
          }),
        ),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Thông số kỹ thuật',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF42506A),
            ),
          ),
          const SizedBox(height: 8),
          _SpecTable(specs: specs),
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
              enabled: widget.quantity > 1,
              onTap: () => widget.onQuantityChanged(widget.quantity - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '${widget.quantity}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _QtyBtn(
              icon: Icons.add,
              enabled: widget.maxStock > 0 && widget.quantity < widget.maxStock,
              onTap: () => widget.onQuantityChanged(widget.quantity + 1),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.maxStock > 0
              ? 'Còn ${widget.maxStock} sản phẩm trong kho'
              : 'Hết hàng',
          style: TextStyle(
            fontSize: 12,
            color: widget.maxStock > 0
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF6F6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE60023)
                  : const Color(0xFFD9DEE8),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0xFFE60023).withValues(alpha: 0.08)
                    : const Color(0xFF0B3A7A).withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? const Color(0xFFB00020)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7893),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.check_circle,
                    size: 22,
                    color: Color(0xFFE60023),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.specs});

  final Map<String, dynamic> specs;

  @override
  Widget build(BuildContext context) {
    final entries = specs.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E8F4)),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final isLast = index == entries.length - 1;
          return Container(
            decoration: BoxDecoration(
              color: index.isEven ? Colors.white : const Color(0xFFF8FBFF),
              borderRadius: isLast
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : BorderRadius.zero,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          entry.key,
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
                          _specValueText(entry.value),
                          style: const TextStyle(
                            color: Color(0xFF17243D),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE1E8F4),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

String _specValueText(dynamic value) {
  if (value == null) {
    return '-';
  }
  if (value is Iterable) {
    return value.map((item) => '$item').join(', ');
  }
  return '$value';
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
    final hasDiscount = detail?.hasSalePrice == true || summary.hasSalePrice;
    final statusLabel = productStatusLabel(detail?.status ?? summary.status);

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
                ProductBadge(
                  label: statusLabel,
                  backgroundColor: const Color(0xFF0C8C71),
                ),
                const SizedBox(width: 10),
                if (hasDiscount) ...[
                  const ProductBadge(
                    label: 'Giảm giá',
                    backgroundColor: Color(0xFFD28A00),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(width: 10),
                ],
                if (detail?.stockQuantity != null)
                  ProductBadge(
                    label: 'Tồn kho: ${detail!.stockQuantity}',
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
                    formatCurrency(price),
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
                        formatCurrency(originalPrice),
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
        child: Icon(Icons.memory_rounded, size: 54, color: Colors.white),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.memory_rounded, size: 54, color: Colors.white),
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
        border: Border.all(color: const Color(0xFFE1E8F4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3A7A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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

class _RelatedProductsSection extends StatelessWidget {
  const _RelatedProductsSection({
    required this.future,
    required this.currentSummary,
  });

  final Future<List<ProductItemSummary>> future;
  final ProductItemSummary currentSummary;

  @override
  Widget build(BuildContext context) {
    final categoryName = currentSummary.category?.name;
    final brandName = currentSummary.brand?.name;
    final subtitle = categoryName != null && categoryName.isNotEmpty
        ? 'Cùng danh mục${brandName != null && brandName.isNotEmpty ? ' · $brandName' : ''}'
        : 'Gợi ý nổi bật';

    return _SectionCard(
      title: 'Sản phẩm liên quan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7893),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: FutureBuilder<List<ProductItemSummary>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1F67E2),
                    ),
                  );
                }

                final items = snapshot.data ?? const <ProductItemSummary>[];
                if (items.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F9FD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE1E8F4)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1F67E2),
                          size: 28,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Chưa có sản phẩm liên quan phù hợp.',
                          style: TextStyle(
                            color: Color(0xFF17243D),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Thử xem thêm các sản phẩm khác trong danh mục.',
                          style: TextStyle(
                            color: Color(0xFF6B7893),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return SizedBox(
                      width: 172,
                      child: _RelatedProductCard(
                        summary: product,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(summary: product),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({required this.summary, required this.onTap});

  final ProductItemSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = summary.mainImageUrl;
    final currentPrice = summary.salePrice ?? summary.price;
    final originalPrice = summary.hasSalePrice ? summary.price : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3EAF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 108,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: _RelatedProductImage(url: imageUrl)),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: ProductBadge(
                        label: productStatusLabel(summary.status),
                        backgroundColor: const Color(0xFF0C8C71),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.category?.name ?? summary.sku ?? 'Sản phẩm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F67E2),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17243D),
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentPrice != null)
                      Text(
                        formatCurrency(currentPrice),
                        style: const TextStyle(
                          color: Color(0xFF1F67E2),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      const Text(
                        'Giá đang cập nhật',
                        style: TextStyle(
                          color: Color(0xFF5F6B82),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (originalPrice != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatCurrency(originalPrice),
                        style: const TextStyle(
                          color: Color(0xFF91A0B8),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Color(0xFF5F6B82),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary.stockQuantity != null
                                ? 'Còn ${summary.stockQuantity} sản phẩm'
                                : 'Còn hàng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF5F6B82),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedProductImage extends StatelessWidget {
  const _RelatedProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(Icons.memory_rounded, size: 40, color: Color(0xFF1F67E2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.memory_rounded,
              size: 40,
              color: Color(0xFF1F67E2),
            ),
          );
        },
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
