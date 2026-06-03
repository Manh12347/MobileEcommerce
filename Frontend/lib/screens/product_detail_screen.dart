import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../providers/product_view_history_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../widgets/product_badge.dart';
import '../utils/app_globals.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/chat_bubble.dart';
import 'checkout_screen.dart';

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
  late Future<List<ProductItemVariantSummary>> _variantsFuture;
  ProductItemVariantSummary? _selectedVariant;
  int _quantity = 1;
  bool _isAdding = false;
  // Stable image URL: only set after confirmed fetch/precache, never stale fallbacks
  String? _selectedVariantImageUrl;
  // Pending variant ID: image for this variant is still loading
  int? _imagePendingVariantId;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
    _variantsFuture = _loadVariants();
  }

  @override
  void dispose() {
    if (ChatbotContext.activeScreen == 'ProductDetail') {
      ChatbotContext.activeScreen = 'Home';
      ChatbotContext.activeProductId = null;
      ChatbotContext.activeProductDetails = null;
    }
    super.dispose();
  }

  void _updateChatbotContext(ProductItemDetail? detail) {
    ChatbotContext.activeScreen = 'ProductDetail';
    ChatbotContext.activeProductId = widget.summary.productItemId ?? widget.summary.productId;
    final specsList = <String>[];
    if (detail != null) {
      detail.specifications.forEach((k, v) {
        specsList.add('$k: $v');
      });
    }
    ChatbotContext.activeProductDetails = 'Name: ${widget.summary.name}, Specs: ${specsList.join(", ")}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Record view after the first frame renders so all data is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordViewHistory();
    });
  }

  Future<void> _recordViewHistory() async {
    if (!mounted) return;
    final history = context.read<ProductViewHistoryProvider>();
    final productId = widget.summary.productId ?? widget.summary.productItemId ?? 0;

    if (_selectedVariant != null) {
      await history.recordView(ViewHistoryEntry.fromVariant(
        _selectedVariant!,
        widget.summary.name,
        productId: productId,
        summaryImageUrl: widget.summary.mainImageUrl,
      ));
    } else {
      await history.recordView(ViewHistoryEntry.fromSummary(widget.summary));
    }
  }

  Future<void> _selectVariant(ProductItemVariantSummary variant) async {
    final currentVariantId = variant.productItemId;

    // Immediately show loading state — keep current image until new one is ready
    setState(() {
      _selectedVariant = variant;
      _imagePendingVariantId = currentVariantId;
      _isImageLoading = true;
    });

    String? resolvedImage;

    // Priority 1: variant has its own image
    if (variant.mainImageUrl != null && variant.mainImageUrl!.isNotEmpty) {
      resolvedImage = variant.mainImageUrl;
    } else if (variant.images.isNotEmpty) {
      resolvedImage = variant.images.first;
    }

    // Priority 2: find from the already-loaded detail (no extra API call)
    if (resolvedImage == null) {
      final detail = await _detailFuture;
      if (_selectedVariant?.productItemId != currentVariantId) return;
      if (detail != null && detail.images.isNotEmpty) {
        resolvedImage = detail.images.first;
      }
    }

    // Priority 3: fetch full detail for this specific productItemId
    if (resolvedImage == null) {
      final pid = variant.productItemId;
      if (pid != null) {
        try {
          final resp = await ApiService.getProductItemDetail(pid);
          if (!mounted) return;
          if (_selectedVariant?.productItemId != currentVariantId) return;
          if (resp.success && resp.data != null) {
            resolvedImage = resp.data!.mainImageUrl ??
                (resp.data!.images.isNotEmpty ? resp.data!.images.first : null);
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    if (_selectedVariant?.productItemId != currentVariantId) return;

    // Only update image if we have a confirmed one
    if (resolvedImage != null) {
      try {
        await precacheImage(NetworkImage(resolvedImage), context);
      } catch (_) {}
      if (!mounted) return;
      if (_selectedVariant?.productItemId != currentVariantId) return;
      setState(() {
        _selectedVariantImageUrl = resolvedImage;
        _isImageLoading = false;
      });
    } else {
      setState(() {
        _selectedVariantImageUrl = null;
        _isImageLoading = false;
      });
    }

    // Update view history
    if (!mounted) return;
    final productId = widget.summary.productId ?? widget.summary.productItemId ?? 0;
    await context.read<ProductViewHistoryProvider>().recordView(
          ViewHistoryEntry.fromVariant(
            variant,
            widget.summary.name,
            productId: productId,
            summaryImageUrl: widget.summary.mainImageUrl,
          ),
        );
  }

  int _maxStock(ProductItemDetail? detail) {
    return _selectedVariant?.stockQuantity ??
        detail?.stockQuantity ??
        widget.summary.stockQuantity ??
        0;
  }

  int? _effectiveProductItemId(ProductItemDetail? detail) {
    return _selectedVariant?.productItemId ?? detail?.id ?? widget.summary.id;
  }

  String? _effectiveStatus(ProductItemDetail? detail) {
    return _selectedVariant?.status ?? detail?.status ?? widget.summary.status;
  }

  double? _effectivePrice(ProductItemDetail? detail) {
    return _selectedVariant?.salePrice ??
        _selectedVariant?.price ??
        detail?.salePrice ??
        detail?.price ??
        widget.summary.salePrice ??
        widget.summary.price;
  }

  double? _effectiveOriginalPrice(ProductItemDetail? detail) {
    if (_selectedVariant?.hasSalePrice == true) {
      return _selectedVariant?.price;
    }
    if (detail?.hasSalePrice == true) {
      return detail?.price;
    }
    if (widget.summary.hasSalePrice) {
      return widget.summary.price;
    }
    return null;
  }

  String? _effectiveDescription(ProductItemDetail? detail) {
    final variantDescription = _selectedVariant?.description?.trim();
    if (variantDescription != null && variantDescription.isNotEmpty) {
      return variantDescription;
    }
    final detailDescription = detail?.description?.trim();
    if (detailDescription != null && detailDescription.isNotEmpty) {
      return detailDescription;
    }
    return null;
  }

  String? _effectiveSku(ProductItemDetail? detail) {
    final variantSku = _selectedVariant?.sku?.trim();
    if (variantSku != null && variantSku.isNotEmpty) {
      return variantSku;
    }
    final detailSku = detail?.sku?.trim();
    if (detailSku != null && detailSku.isNotEmpty) {
      return detailSku;
    }
    final summarySku = widget.summary.sku?.trim();
    if (summarySku != null && summarySku.isNotEmpty) {
      return summarySku;
    }
    return null;
  }

  bool _canPurchase(ProductItemDetail? detail) {
    final status = _effectiveStatus(detail);
    return isActiveProductStatus(status) && _maxStock(detail) > 0;
  }

  Future<bool> _submitCartAction(
    ProductItemDetail? detail, {
    required bool navigateToCart,
  }) async {
    final productItemId = _effectiveProductItemId(detail);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm $_quantity sản phẩm vào giỏ')),
        );

        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return false;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
        );
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
    final productItemId = _effectiveProductItemId(detail);
    if (productItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được sản phẩm')),
      );
      return;
    }

    final stock = _maxStock(detail);
    if (stock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sản phẩm đã hết hàng')));
      return;
    }

    if (_quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chỉ còn $stock sản phẩm trong kho')),
      );
      return;
    }

    final name = detail?.productName ?? widget.summary.name;
    final description = _effectiveDescription(detail);
    final String fullName = description != null && description.isNotEmpty
        ? "$name - $description"
        : name;

    final price = _effectiveOriginalPrice(detail) ?? _effectivePrice(detail);
    final salePrice = _effectiveOriginalPrice(detail) != null ? _effectivePrice(detail) : null;
    final double unitPrice = _effectivePrice(detail) ?? 0;

    final cartItem = CartItem(
      cartItemId: 0,
      productItemId: productItemId,
      quantity: _quantity,
      sku: _effectiveSku(detail),
      productName: fullName,
      mainImageUrl: _selectedVariantImageUrl ?? detail?.mainImageUrl ?? widget.summary.mainImageUrl,
      price: price,
      salePrice: salePrice,
      lineTotal: unitPrice * _quantity,
    );

    final directCart = Cart(
      cartId: 0,
      accountId: 0,
      items: [cartItem],
      totalItems: _quantity,
      totalAmount: unitPrice * _quantity,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(directBuyCart: directCart),
      ),
    );
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

  Future<List<ProductItemVariantSummary>> _loadVariants() async {
    final productId = widget.summary.productId;
    if (productId == null) {
      return const [];
    }

    try {
      final response = await ApiService.getProductItemVariants(productId);
      if (!response.success) {
        return const [];
      }
      return response.data ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
      _variantsFuture = _loadVariants();
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const ChatBubbleButton(),
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateChatbotContext(detail);
            });
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _ProductHeroCard(
                  summary: widget.summary,
                  detail: detail,
                  selectedVariant: _selectedVariant,
                  selectedVariantImageUrl: _selectedVariantImageUrl,
                  isImageLoading: _isImageLoading,
                  imagePendingVariantId: _imagePendingVariantId,
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ProductItemVariantSummary>>(
                  future: _variantsFuture,
                  builder: (context, vsnap) {
                    final variants = vsnap.data ?? const [];
                    if (_selectedVariant == null && variants.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _selectVariant(variants.first);
                      });
                    }
                    return _SectionCard(
                      title: 'Phiên bản',
                      child: _VariantSelector(
                        detail: detail,
                        variants: variants,
                        selectedVariant: _selectedVariant,
                        onSelectedVariant: (v) => _selectVariant(v),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Thông tin chính',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Phiên bản',
                        value: _effectiveSku(detail) ?? '-',
                      ),
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
                        value: productStatusLabel(_effectiveStatus(detail)),
                      ),
                      _InfoRow(
                        label: 'Tồn kho',
                        value: _maxStock(detail) > 0
                            ? '${_maxStock(detail)}'
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
                    _effectiveDescription(detail)?.isNotEmpty == true
                        ? _effectiveDescription(detail)!
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
                  title: 'Cấu hình sản phẩm',
                  child: (detail?.specifications.isNotEmpty == true)
                      ? _SpecTable(specs: detail!.specifications)
                      : const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Chưa có thông số kỹ thuật cho sản phẩm này.',
                            style: TextStyle(
                              color: Color(0xFF6B7893),
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                const _ViewHistorySection(),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                  const SizedBox(height: 10),
                  AppBottomNav(
                    currentIndex: 0,
                    cartBadgeCount: context.watch<CartProvider>().itemCount,
                    onTap: (index) {
                      navigateToTabNotifier.value = index;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
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

// ─── View History Section ─────────────────────────────────────────────────────

class _ViewHistorySection extends StatelessWidget {
  const _ViewHistorySection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductViewHistoryProvider>(
      builder: (context, history, _) {
        final items = history.recentHistory;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return _SectionCard(
          title: 'Đã xem gần đây',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: 160,
                      child: _ViewHistoryCard(
                        entry: item,
                        onTap: () {
                          // Navigate to product detail using the summary from context
                          final summary = ProductItemSummary(
                            productItemId: item.productId,
                            productId: item.productId,
                            productName: item.name,
                            mainImageUrl: item.mainImageUrl,
                            salePrice: item.salePrice,
                            price: item.price,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(summary: summary),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmClearHistory(context, history),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7893),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Xóa lịch sử',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearHistory(
    BuildContext context,
    ProductViewHistoryProvider history,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lịch sử xem?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              history.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFE60023)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewHistoryCard extends StatelessWidget {
  const _ViewHistoryCard({required this.entry, required this.onTap});

  final ViewHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentPrice = entry.salePrice ?? entry.price;
    final originalPrice = entry.salePrice != null ? entry.price : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EAF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 96,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  gradient: LinearGradient(
                    colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _HistoryProductImage(url: entry.mainImageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF17243D),
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (currentPrice != null) ...[
                        Text(
                          formatCurrency(currentPrice),
                          style: const TextStyle(
                            color: Color(0xFF1F67E2),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (originalPrice != null)
                          Text(
                            formatCurrency(originalPrice),
                            style: const TextStyle(
                              color: Color(0xFF91A0B8),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryProductImage extends StatelessWidget {
  const _HistoryProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(Icons.memory_rounded, size: 36, color: Color(0xFF1F67E2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.memory_rounded, size: 36, color: Color(0xFF1F67E2)),
        ),
      ),
    );
  }
}

// ─── Variant Selector ─────────────────────────────────────────────────────────

class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.detail,
    required this.variants,
    required this.selectedVariant,
    required this.onSelectedVariant,
  });

  final ProductItemDetail? detail;
  final List<ProductItemVariantSummary> variants;
  final ProductItemVariantSummary? selectedVariant;
  final ValueChanged<ProductItemVariantSummary> onSelectedVariant;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      final sku =
          detail?.sku ?? detail?.productName ?? 'Phiên bản hiện tại';
      return _VersionCard(
        label: sku,
        selected: true,
        onTap: () {},
      );
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
          children: List.generate(variants.length, (index) {
            final variant = variants[index];
            final selected = selectedVariant?.productItemId ==
                variant.productItemId;
            return SizedBox(
              width: 160,
              child: _VersionCard(
                label: variant.label,
                selected: selected,
                onTap: () => onSelectedVariant(variant),
              ),
            );
          }),
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

// ─── Spec Table ───────────────────────────────────────────────────────────────

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

// ─── Hero Card ────────────────────────────────────────────────────────────────

class _ProductHeroCard extends StatelessWidget {
  const _ProductHeroCard({
    required this.summary,
    required this.detail,
    required this.selectedVariant,
    this.selectedVariantImageUrl,
    required this.isImageLoading,
    required this.imagePendingVariantId,
  });

  final ProductItemSummary summary;
  final ProductItemDetail? detail;
  final ProductItemVariantSummary? selectedVariant;
  final String? selectedVariantImageUrl;
  final bool isImageLoading;
  final int? imagePendingVariantId;

  String? get _effectiveImage {
    // While image is being fetched, suppress fallback to avoid showing stale variant image
    if (this.isImageLoading && this.selectedVariantImageUrl == null) return null;
    if (selectedVariantImageUrl != null) return selectedVariantImageUrl;
    if (selectedVariant?.mainImageUrl != null &&
        selectedVariant!.mainImageUrl!.isNotEmpty) {
      return selectedVariant!.mainImageUrl;
    }
    if (selectedVariant?.images.isNotEmpty == true) {
      return selectedVariant!.images.first;
    }
    if (detail?.mainImageUrl != null && detail!.mainImageUrl!.isNotEmpty) {
      return detail!.mainImageUrl;
    }
    if (detail?.images.isNotEmpty == true) {
      return detail!.images.first;
    }
    return summary.mainImageUrl;
  }

  double? get _effectivePrice {
    return selectedVariant?.salePrice ??
        selectedVariant?.price ??
        detail?.salePrice ??
        detail?.price ??
        summary.salePrice ??
        summary.price;
  }

  double? get _effectiveOriginalPrice {
    if (selectedVariant?.hasSalePrice == true) {
      return selectedVariant?.price;
    }
    if (detail?.hasSalePrice == true) {
      return detail?.price;
    }
    if (summary.hasSalePrice) {
      return summary.price;
    }
    return null;
  }

  String? get _effectiveSku {
    return selectedVariant?.sku?.trim() ?? detail?.sku?.trim();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _effectiveImage;
    final price = _effectivePrice;
    final originalPrice = _effectiveOriginalPrice;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3A7A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: 320,
              color: const Color(0xFFF6F9FD),
              child: _HeroImage(
                url: _effectiveImage,
                isLoading: isImageLoading,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  style: const TextStyle(
                    color: Color(0xFF17243D),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                if (_effectiveSku != null && _effectiveSku!.isNotEmpty)
                  Text(
                    _effectiveSku!,
                    style: const TextStyle(
                      color: Color(0xFF6B7893),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 12),
                if (price != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(price),
                        style: const TextStyle(
                          color: Color(0xFF1F67E2),
                          fontSize: 26,
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
                              color: Color(0xFF91A0B8),
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
                      color: Color(0xFF5F6B82),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url, this.isLoading = false});

  final String? url;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(Icons.memory_rounded, size: 74, color: Colors.white),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Image.network(
            url!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: const Color(0xFF1F67E2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.memory_rounded, size: 74, color: Colors.white),
            ),
          ),
        ),
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1F67E2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

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

// ─── Info Row ─────────────────────────────────────────────────────────────────

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
