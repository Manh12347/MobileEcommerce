import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../utils/app_globals.dart';
import '../utils/format_utils.dart';
import '../widgets/product_badge.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const int _pageSize = 16;

  bool _isLoading = true;
  String? _error;
  List<ProductItemSummary> _catalogProducts = const [];
  List<_CatalogProduct> _products = const [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  int? _selectedBrandId;
  int? _selectedCategoryId;
  int? _selectedProductId;
  RangeValues? _priceRange;
  String _sortBy = 'newest';
  String _sortDir = 'desc';

  Timer? _priceDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
      _products = const [];
    });
    try {
      final response = await ApiService.getProductItems(page: 1, size: 200);
      if (!mounted) return;
      setState(() {
        _catalogProducts = (response.data ?? const [])
            .where((product) => isActiveProductStatus(product.status))
            .toList();
        _priceRange ??= RangeValues(_minAvailablePrice, _maxAvailablePrice);
      });
      await _loadProducts(reset: true);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
    }
    _error = null;

    try {
      final response = await ApiService.getProductItems(
        page: _currentPage,
        size: _pageSize,
        brandId: _selectedBrandId,
        categoryId: _selectedCategoryId,
        productId: _selectedProductId,
        minPrice: _priceRange?.start,
        maxPrice: _priceRange?.end,
        sortBy: _sortBy,
        sortDir: _sortDir,
      );

      if (!mounted) return;

      final summaries = response.data ?? const <ProductItemSummary>[];
      final Map<int, ProductItemSummary> uniqueByProduct = {};
      for (final summary in summaries) {
        if (!isActiveProductStatus(summary.status)) continue;
        final key = summary.productId ?? summary.productItemId ?? 0;
        if (key == 0) continue;
        uniqueByProduct.putIfAbsent(key, () => summary);
      }

      final loadedProducts = uniqueByProduct.values
          .map((s) => _CatalogProduct(summary: s))
          .toList();

      // Prefetch first variant for each product
      await Future.wait(loadedProducts.map((p) async {
        final pid = p.summary.productId;
        if (pid == null) return;
        try {
          final resp = await ApiService.getProductItemVariants(pid);
          if (resp.success && resp.data != null && resp.data!.isNotEmpty) {
            final v = resp.data!.first;
            final hasImages =
                (v.mainImageUrl != null && v.mainImageUrl!.isNotEmpty) ||
                    (v.images.isNotEmpty);
            if (!hasImages && v.productItemId != null) {
              try {
                final detResp =
                    await ApiService.getProductItemDetail(v.productItemId!);
                if (detResp.success && detResp.data != null) {
                  final det = detResp.data!;
                  p.firstVariant = ProductItemVariantSummary(
                    productItemId: v.productItemId,
                    sku: v.sku,
                    description: v.description,
                    stockQuantity: v.stockQuantity,
                    status: v.status,
                    price: v.price,
                    salePrice: v.salePrice,
                    imagesRaw: det.imagesRaw ?? v.imagesRaw,
                    mainImageUrl: det.mainImageUrl ?? v.mainImageUrl,
                  );
                } else {
                  p.firstVariant = v;
                }
              } catch (_) {
                p.firstVariant = v;
              }
            } else {
              p.firstVariant = v;
            }
          }
        } catch (_) {}
      }));

      if (!mounted) return;

      final hasMore = summaries.length >= _pageSize;
      setState(() {
        if (reset) {
          _products = loadedProducts;
        } else {
          _products = [..._products, ...loadedProducts];
        }
        _hasMore = hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadProducts();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  double get _minAvailablePrice {
    final prices = _catalogProducts
        .map((product) => product.salePrice ?? product.price)
        .whereType<double>()
        .toList();
    if (prices.isEmpty) return 0;
    return prices.reduce((left, right) => left < right ? left : right);
  }

  double get _maxAvailablePrice {
    final prices = _catalogProducts
        .map((product) => product.salePrice ?? product.price)
        .whereType<double>()
        .toList();
    if (prices.isEmpty) return 1;
    return prices.reduce((left, right) => left > right ? left : right);
  }

  RangeValues get _effectivePriceRange =>
      _priceRange ?? RangeValues(_minAvailablePrice, _maxAvailablePrice);

  List<_FilterOption> get _brandOptions {
    final options = <_FilterOption>[];
    final seen = <int>{};
    for (final product in _catalogProducts) {
      final brand = product.brand;
      final brandId = brand?.brandId;
      final brandName = brand?.name?.trim();
      if (brandId == null || brandName == null || brandName.isEmpty) {
        continue;
      }
      if (seen.add(brandId)) {
        options.add(_FilterOption(id: brandId, label: brandName));
      }
    }
    options.sort(
        (left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
    return options;
  }

  List<_FilterOption> get _categoryOptions {
    final options = <_FilterOption>[];
    final seen = <int>{};
    final scopedProducts = _catalogProducts.where((product) {
      final brandId = product.brand?.brandId;
      return _selectedBrandId == null || brandId == _selectedBrandId;
    });
    for (final product in scopedProducts) {
      final category = product.category;
      final categoryId = category?.categoryId;
      final categoryName = category?.name?.trim();
      if (categoryId == null || categoryName == null || categoryName.isEmpty) {
        continue;
      }
      if (seen.add(categoryId)) {
        options.add(_FilterOption(id: categoryId, label: categoryName));
      }
    }
    options.sort(
        (left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
    return options;
  }

  List<_FilterOption> get _productOptions {
    final options = <_FilterOption>[];
    final seen = <int>{};
    final scopedProducts = _catalogProducts.where((product) {
      final brandId = product.brand?.brandId;
      final categoryId = product.category?.categoryId;
      final brandMatch = _selectedBrandId == null || brandId == _selectedBrandId;
      final categoryMatch =
          _selectedCategoryId == null || categoryId == _selectedCategoryId;
      return brandMatch && categoryMatch;
    });
    for (final product in scopedProducts) {
      final productId = product.productId;
      final productName = product.productName?.trim();
      if (productId == null || productName == null || productName.isEmpty) {
        continue;
      }
      if (seen.add(productId)) {
        options.add(_FilterOption(id: productId, label: productName));
      }
    }
    options.sort(
        (left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Danh mục',
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
          const SizedBox(height: 100),
          Center(child: Text(_error!)),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _InlineFilterPanel(
              brandOptions: _brandOptions,
              categoryOptions: _categoryOptions,
              productOptions: _productOptions,
              selectedBrandId: _selectedBrandId,
              selectedCategoryId: _selectedCategoryId,
              selectedProductId: _selectedProductId,
              priceRange: _effectivePriceRange,
              minAvailablePrice: _minAvailablePrice,
              maxAvailablePrice: _maxAvailablePrice,
              sortBy: _sortBy,
              sortDir: _sortDir,
              onBrandChanged: _onBrandChanged,
              onCategoryChanged: _onCategoryChanged,
              onProductChanged: _onProductChanged,
              onPriceChanged: _onPriceChanged,
              onSortByChanged: _onSortChanged,
              onSortDirChanged: _onSortDirChanged,
              onClearTap: _clearFilters,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_products.length} sản phẩm',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14213D),
                  ),
                ),
                Text(
                  _sortLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7893),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Không có sản phẩm trong danh mục này')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: Builder(builder: (context) {
              final mq = MediaQuery.of(context);
              final height = mq.size.height;
              final dpr = mq.devicePixelRatio;
              final scale =
                  (height / 800).clamp(0.85, 1.2) * (dpr >= 2.5 ? 1.05 : 1.0);

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14 * scale,
                  crossAxisSpacing: 14 * scale,
                  childAspectRatio: 0.52 / scale,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = _products[index];
                  return _CategoryProductCard(
                    product: product,
                    uiScale: scale,
                    onTap: () => _openProductDetail(product),
                    onAddToCart: () => _addToCart(product),
                    onBuyNow: () => _buyNow(product),
                  );
                }, childCount: _products.length),
              );
            }),
          ),
        // Load more
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF1F67E2),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Tải thêm'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F67E2),
                          side: const BorderSide(color: Color(0xFF1F67E2)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        if (!_hasMore && _products.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: Text(
                  'Đã hiển thị tất cả sản phẩm',
                  style: TextStyle(
                    color: Color(0xFF6B7893),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedBrandId = null;
      _selectedCategoryId = null;
      _selectedProductId = null;
      _priceRange = RangeValues(_minAvailablePrice, _maxAvailablePrice);
      _sortBy = 'newest';
      _sortDir = 'desc';
    });
    await _loadProducts(reset: true);
  }

  String get _priceRangeLabel {
    final range = _effectivePriceRange;
    return '${formatCurrency(range.start)} - ${formatCurrency(range.end)}';
  }

  String get _sortLabel {
    final label = switch (_sortBy) {
      'brand' => 'Thương hiệu',
      'category' => 'Danh mục',
      'product' => 'Sản phẩm',
      'price' => 'Khung giá',
      _ => 'Mới nhất',
    };
    return '$label ${_sortDir == 'asc' ? '↑' : '↓'}';
  }

  Future<void> _onBrandChanged(int? value) async {
    setState(() {
      _selectedBrandId = value;
      _selectedCategoryId = null;
      _selectedProductId = null;
    });
    await _loadProducts(reset: true);
  }

  Future<void> _onCategoryChanged(int? value) async {
    setState(() {
      _selectedCategoryId = value;
      _selectedProductId = null;
    });
    await _loadProducts(reset: true);
  }

  Future<void> _onProductChanged(int? value) async {
    setState(() => _selectedProductId = value);
    await _loadProducts(reset: true);
  }

  Future<void> _onPriceChanged(RangeValues value) async {
    setState(() => _priceRange = value);
    // Debounce: only call API 600ms after user stops dragging
    _priceDebounce?.cancel();
    _priceDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _loadProducts(reset: true);
    });
  }

  Future<void> _onSortChanged(String? value) async {
    setState(() => _sortBy = value ?? 'newest');
    await _loadProducts(reset: true);
  }

  Future<void> _onSortDirChanged(String? value) async {
    setState(() => _sortDir = value ?? 'desc');
    await _loadProducts(reset: true);
  }

  void _openProductDetail(_CatalogProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailScreen(summary: product.summary, initialDetail: null),
      ),
    );
  }

  Future<void> _buyNow(_CatalogProduct product) async {
    final summary = product.summary;
    var productItemId = summary.id;

    // If productItemId is null (no variant), try to fetch the first variant
    if (productItemId == null) {
      final pid = summary.productId;
      if (pid != null) {
        try {
          final resp = await ApiService.getProductItemVariants(pid);
          if (resp.success && resp.data != null && resp.data!.isNotEmpty) {
            productItemId = resp.data!.first.productItemId;
          }
        } catch (_) {}
        if (!mounted) return;
      }
    }

    if (productItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được sản phẩm')),
      );
      return;
    }

    if (!isActiveProductStatus(summary.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm hiện không thể mua')),
      );
      return;
    }

    final price = summary.price;
    final salePrice = summary.salePrice;
    final double unitPrice = salePrice != null && price != null && salePrice < price
        ? salePrice
        : (salePrice ?? price ?? 0);

    final cartItem = CartItem(
      cartItemId: 0,
      productItemId: productItemId,
      quantity: 1,
      sku: summary.sku,
      productName: summary.name,
      mainImageUrl: summary.mainImageUrl,
      price: price,
      salePrice: salePrice,
      lineTotal: unitPrice,
    );

    final directCart = Cart(
      cartId: 0,
      accountId: 0,
      items: [cartItem],
      totalItems: 1,
      totalAmount: unitPrice,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(directBuyCart: directCart),
      ),
    );
  }

  Future<void> _addToCart(_CatalogProduct product) async {
    final summary = product.summary;
    var productItemId = product.firstVariant?.productItemId ?? summary.id;

    if (productItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được sản phẩm')),
      );
      return;
    }

    if (!isActiveProductStatus(summary.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm hiện không thể mua')),
      );
      return;
    }

    final cartProvider = context.read<CartProvider>();
    final ok = await cartProvider.addToCart(
      productItemId: productItemId,
      quantity: 1,
    );

    if (!mounted) return;

    if (ok) {
      context.read<CartProvider>().loadCart(silent: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào giỏ hàng thành công'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final errorMessage = cartProvider.errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage.isNotEmpty ? errorMessage : 'Không thêm được vào giỏ',
        ),
      ),
    );
  }
}

class _FilterOption {
  final Object? id;
  final String label;

  const _FilterOption({required this.id, required this.label});
}

class _InlineFilterPanel extends StatelessWidget {
  const _InlineFilterPanel({
    required this.brandOptions,
    required this.categoryOptions,
    required this.productOptions,
    required this.selectedBrandId,
    required this.selectedCategoryId,
    required this.selectedProductId,
    required this.priceRange,
    required this.minAvailablePrice,
    required this.maxAvailablePrice,
    required this.sortBy,
    required this.sortDir,
    required this.onBrandChanged,
    required this.onCategoryChanged,
    required this.onProductChanged,
    required this.onPriceChanged,
    required this.onSortByChanged,
    required this.onSortDirChanged,
    required this.onClearTap,
  });

  final List<_FilterOption> brandOptions;
  final List<_FilterOption> categoryOptions;
  final List<_FilterOption> productOptions;
  final int? selectedBrandId;
  final int? selectedCategoryId;
  final int? selectedProductId;
  final RangeValues priceRange;
  final double minAvailablePrice;
  final double maxAvailablePrice;
  final String sortBy;
  final String sortDir;
  final Future<void> Function(int?) onBrandChanged;
  final Future<void> Function(int?) onCategoryChanged;
  final Future<void> Function(int?) onProductChanged;
  final Future<void> Function(RangeValues) onPriceChanged;
  final Future<void> Function(String?) onSortByChanged;
  final Future<void> Function(String?) onSortDirChanged;
  final Future<void> Function() onClearTap;

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Text(
                  'Bộ lọc',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14213D),
                  ),
                ),
              ),
              TextButton(
                onPressed: onClearTap,
                child: const Text('Xóa lọc'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FilterDropdown<int?>(
            label: 'Thương hiệu',
            value: selectedBrandId,
            items: [
              const _FilterOption(id: null, label: 'Tất cả'),
              ...brandOptions,
            ],
            onChanged: onBrandChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown<int?>(
            label: 'Danh mục',
            value: selectedCategoryId,
            items: [
              const _FilterOption(id: null, label: 'Tất cả'),
              ...categoryOptions,
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          _FilterDropdown<int?>(
            label: 'Sản phẩm',
            value: selectedProductId,
            items: [
              const _FilterOption(id: null, label: 'Tất cả'),
              ...productOptions,
            ],
            onChanged: onProductChanged,
          ),
          const SizedBox(height: 16),
          Text(
            'Giá',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF14213D),
                ),
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: priceRange,
            min: minAvailablePrice,
            max: maxAvailablePrice,
            labels: RangeLabels(
              formatCurrency(priceRange.start),
              formatCurrency(priceRange.end),
            ),
            onChanged: onPriceChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatCurrency(priceRange.start)),
              Text(formatCurrency(priceRange.end)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String?>(
                  label: 'Lọc',
                  value: sortBy,
                  items: const [
                    _FilterOption(id: 'newest', label: 'Mới nhất'),
                    _FilterOption(id: 'oldest', label: 'Cũ nhất'),
                  ],
                  onChanged: onSortByChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterDropdown<String?>(
                  label: 'Thứ tự',
                  value: sortDir,
                  items: const [
                    _FilterOption(id: 'desc', label: 'Giảm dần'),
                    _FilterOption(id: 'asc', label: 'Tăng dần'),
                  ],
                  onChanged: onSortDirChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<_FilterOption> items;
  final Future<void> Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Object?>(
      value: value as Object?,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<Object?>(
              value: item.id,
              child: Text(item.label),
            ),
          )
          .toList(),
      onChanged: (selected) async {
        await onChanged(selected as T);
      },
    );
  }
}

class _CatalogProduct {
  final ProductItemSummary summary;
  ProductItemVariantSummary? firstVariant;

  _CatalogProduct({required this.summary, this.firstVariant});
}

class _CategoryProductCard extends StatefulWidget {
  const _CategoryProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    required this.onBuyNow,
    this.uiScale = 1.0,
  });

  final _CatalogProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final double uiScale;

  @override
  State<_CategoryProductCard> createState() => _CategoryProductCardState();
}

class _CategoryProductCardState extends State<_CategoryProductCard> {
  @override
  Widget build(BuildContext context) {
    final summary = widget.product.summary;
    final variant = widget.product.firstVariant;
    final variantImage = variant?.mainImageUrl ??
        (variant?.images.isNotEmpty == true ? variant!.images.first : null);
    final imageUrl = variantImage ?? summary.mainImageUrl;
    final currentPrice = variant?.salePrice ??
        variant?.price ??
        summary.salePrice ??
        summary.price;
    final originalPrice = variant?.hasSalePrice == true
        ? variant!.price
        : (summary.hasSalePrice ? summary.price : null);
    final isActive = isActiveProductStatus(variant?.status ?? summary.status);
    final canBuy = isActive;
    final badges = <Widget>[
      if (variant?.hasSalePrice == true ||
          (variant == null && summary.hasSalePrice))
        const ProductBadge(
          label: 'Giảm giá',
          backgroundColor: Color(0xFFD28A00),
          foregroundColor: Colors.white,
        ),
    ];

    final scale = widget.uiScale;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5ECF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 140 * scale,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8 * scale,
                          offset: Offset(0, 4 * scale),
                        ),
                      ],
                    ),
                    child: _CategoryProductImage(url: imageUrl, fit: BoxFit.cover),
                  ),
                  if (badges.isNotEmpty)
                    Positioned(left: 12, top: 12, child: Row(children: badges)),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12 * scale, 12 * scale, 12 * scale, 12 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          variant?.sku ?? summary.sku ?? summary.category?.name ?? 'Sản phẩm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1F67E2),
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        summary.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF17243D),
                          fontSize: 15 * scale,
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      if (currentPrice != null)
                        Text(
                          formatCurrency(currentPrice),
                          style: TextStyle(
                            color: const Color(0xFF1F67E2),
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        Text(
                          'Giá đang cập nhật',
                          style: TextStyle(
                            color: const Color(0xFF5F6B82),
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (originalPrice != null) ...[
                        SizedBox(height: 2 * scale),
                        Text(
                          formatCurrency(originalPrice),
                          style: TextStyle(
                            color: const Color(0xFF91A0B8),
                            fontSize: 12 * scale,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          SizedBox(
                            width: 48 * scale,
                            height: 42 * scale,
                            child: OutlinedButton(
                              onPressed: canBuy ? widget.onAddToCart : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1F67E2),
                                side: const BorderSide(color: Color(0xFF1F67E2)),
                                padding: EdgeInsets.zero,
                                minimumSize: Size(48 * scale, 42 * scale),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Icon(
                                canBuy
                                    ? Icons.shopping_cart_outlined
                                    : Icons.remove_shopping_cart_outlined,
                                size: 18 * scale,
                              ),
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: FilledButton(
                              onPressed: canBuy ? widget.onBuyNow : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1F67E2),
                                disabledBackgroundColor: const Color(0xFFD9E3F2),
                                foregroundColor: Colors.white,
                                minimumSize: Size.fromHeight(42 * scale),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                canBuy ? 'Mua' : 'Hết hàng',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13 * scale,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _CategoryProductImage extends StatelessWidget {
  const _CategoryProductImage({required this.url, this.fit = BoxFit.contain});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(Icons.memory_rounded, size: 54, color: Color(0xFF1F67E2)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        url!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.memory_rounded,
              size: 54,
              color: Color(0xFF1F67E2),
            ),
          );
        },
      ),
    );
  }
}
