import 'package:flutter/material.dart';

import '../models/product_item.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../widgets/product_badge.dart';
import 'product_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProductItemSummary> _catalogProducts = const [];
  List<ProductItemSummary> _products = const [];
  int? _selectedBrandId;
  int? _selectedCategoryId;
  int? _selectedProductId;
  int? _selectedVariantId;
  List<_FilterOption> _variantOptions = const [];
  RangeValues? _priceRange;
  String _sortBy = 'newest';
  String _sortDir = 'desc';

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
      final response = await ApiService.getProductItems(page: 1, size: 200);
      if (!mounted) return;
      setState(() {
        _catalogProducts = (response.data ?? const [])
            .where((product) => isActiveProductStatus(product.status))
            .toList();
        _priceRange ??= RangeValues(_minAvailablePrice, _maxAvailablePrice);
      });
      await _loadProducts();
      if (!mounted) return;
      setState(() {
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

  Future<void> _loadProducts() async {
    _error = null;

    try {
      final response = await ApiService.getProductItems(
        page: 1,
        size: 100,
        brandId: _selectedBrandId,
        categoryId: _selectedCategoryId,
        productId: _selectedProductId,
        productItemId: _selectedVariantId,
        minPrice: _priceRange?.start,
        maxPrice: _priceRange?.end,
        sortBy: _sortBy,
        sortDir: _sortDir,
      );

      if (!mounted) return;
      setState(() {
        _products = (response.data ?? const [])
            .where((product) => isActiveProductStatus(product.status))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
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
    options.sort((left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
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
    options.sort((left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
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
    options.sort((left, right) => left.label.toLowerCase().compareTo(right.label.toLowerCase()));
    return options;
  }

  List<ProductItemSummary> get _visibleProducts => _products;

  String get _selectedBrandLabel {
    if (_selectedBrandId == null) return 'Tất cả';
    return _brandOptions.firstWhere(
          (option) => option.id == _selectedBrandId,
          orElse: () => const _FilterOption(id: null, label: 'Tất cả'),
        )
        .label;
  }

  String get _selectedCategoryLabel {
    if (_selectedCategoryId == null) return 'Tất cả';
    return _categoryOptions.firstWhere(
          (option) => option.id == _selectedCategoryId,
          orElse: () => const _FilterOption(id: null, label: 'Tất cả'),
        )
        .label;
  }

  String get _selectedProductLabel {
    if (_selectedProductId == null) return 'Tất cả';
    return _productOptions.firstWhere(
          (option) => option.id == _selectedProductId,
          orElse: () => const _FilterOption(id: null, label: 'Tất cả'),
        )
        .label;
  }

  String get _selectedVariantLabel {
    if (_selectedVariantId == null) return 'Tất cả';
    return _variantOptions.firstWhere(
          (option) => option.id == _selectedVariantId,
          orElse: () => const _FilterOption(id: null, label: 'Tất cả'),
        )
        .label;
  }

  Future<void> _refreshVariantOptions(int? productId) async {
    if (productId == null) {
      setState(() {
        _variantOptions = const [];
        _selectedVariantId = null;
      });
      return;
    }

    try {
      final response = await ApiService.getProductItemVariants(productId);
      if (!mounted) return;
      setState(() {
        _variantOptions = (response.data ?? const [])
            .map(
              (variant) => _FilterOption(
                id: variant.productItemId,
                label: variant.label,
              ),
            )
            .toList();
        if (_variantOptions.every((option) => option.id != _selectedVariantId)) {
          _selectedVariantId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _variantOptions = const [];
        _selectedVariantId = null;
      });
    }
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

    final products = _visibleProducts;

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
              variantOptions: _variantOptions,
              selectedBrandId: _selectedBrandId,
              selectedCategoryId: _selectedCategoryId,
              selectedProductId: _selectedProductId,
              selectedVariantId: _selectedVariantId,
              priceRange: _effectivePriceRange,
              minAvailablePrice: _minAvailablePrice,
              maxAvailablePrice: _maxAvailablePrice,
              sortBy: _sortBy,
              sortDir: _sortDir,
              onBrandChanged: _onBrandChanged,
              onCategoryChanged: _onCategoryChanged,
              onProductChanged: _onProductChanged,
              onVariantChanged: _onVariantChanged,
              onPriceChanged: _onPriceChanged,
              onSortByChanged: _onSortByChanged,
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
                  'Sản phẩm: ${products.length}',
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
        if (products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Không có sản phẩm trong danh mục này')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return _CategoryProductTile(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(summary: product),
                      ),
                    );
                  },
                );
              },
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
      _selectedVariantId = null;
      _variantOptions = const [];
      _priceRange = RangeValues(_minAvailablePrice, _maxAvailablePrice);
      _sortBy = 'newest';
      _sortDir = 'desc';
    });
    await _loadProducts();
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
      _selectedVariantId = null;
      _variantOptions = const [];
    });
    await _loadProducts();
  }

  Future<void> _onCategoryChanged(int? value) async {
    setState(() {
      _selectedCategoryId = value;
      _selectedProductId = null;
      _selectedVariantId = null;
      _variantOptions = const [];
    });
    await _loadProducts();
  }

  Future<void> _onProductChanged(int? value) async {
    setState(() {
      _selectedProductId = value;
      _selectedVariantId = null;
      _variantOptions = const [];
    });
    await _refreshVariantOptions(value);
    await _loadProducts();
  }

  Future<void> _onVariantChanged(int? value) async {
    setState(() {
      _selectedVariantId = value;
    });
    await _loadProducts();
  }

  Future<void> _onPriceChanged(RangeValues value) async {
    setState(() {
      _priceRange = value;
    });
    await _loadProducts();
  }

  Future<void> _onSortByChanged(String? value) async {
    setState(() {
      _sortBy = value ?? 'newest';
    });
    await _loadProducts();
  }

  Future<void> _onSortDirChanged(String? value) async {
    setState(() {
      _sortDir = value ?? 'desc';
    });
    await _loadProducts();
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
    required this.variantOptions,
    required this.selectedBrandId,
    required this.selectedCategoryId,
    required this.selectedProductId,
    required this.selectedVariantId,
    required this.priceRange,
    required this.minAvailablePrice,
    required this.maxAvailablePrice,
    required this.sortBy,
    required this.sortDir,
    required this.onBrandChanged,
    required this.onCategoryChanged,
    required this.onProductChanged,
    required this.onVariantChanged,
    required this.onPriceChanged,
    required this.onSortByChanged,
    required this.onSortDirChanged,
    required this.onClearTap,
  });

  final List<_FilterOption> brandOptions;
  final List<_FilterOption> categoryOptions;
  final List<_FilterOption> productOptions;
  final List<_FilterOption> variantOptions;
  final int? selectedBrandId;
  final int? selectedCategoryId;
  final int? selectedProductId;
  final int? selectedVariantId;
  final RangeValues priceRange;
  final double minAvailablePrice;
  final double maxAvailablePrice;
  final String sortBy;
  final String sortDir;
  final Future<void> Function(int?) onBrandChanged;
  final Future<void> Function(int?) onCategoryChanged;
  final Future<void> Function(int?) onProductChanged;
  final Future<void> Function(int?) onVariantChanged;
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
            label: 'Brand',
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
          const SizedBox(height: 12),
          _FilterDropdown<int?>(
            label: 'Phiên bản',
            value: selectedVariantId,
            items: [
              const _FilterOption(id: null, label: 'Tất cả'),
              ...variantOptions,
            ],
            onChanged: onVariantChanged,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String?>(
                  label: 'Sort',
                  value: sortBy,
                  items: const [
                    _FilterOption(id: 'newest', label: 'Mới nhất'),
                    _FilterOption(id: 'brand', label: 'Brand'),
                    _FilterOption(id: 'category', label: 'Danh mục'),
                    _FilterOption(id: 'product', label: 'Sản phẩm'),
                    _FilterOption(id: 'price', label: 'Giá'),
                  ],
                  onChanged: onSortByChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterDropdown<String?>(
                  label: 'Tăng/Giảm',
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

class _CategoryProductTile extends StatelessWidget {
  const _CategoryProductTile({required this.product, required this.onTap});

  final ProductItemSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = product.salePrice ?? product.price;
    final hasDiscount = product.hasSalePrice;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EAF5)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product.mainImageUrl != null && product.mainImageUrl!.isNotEmpty
                    ? Image.network(
                        product.mainImageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ProductBadge(label: productStatusLabel(product.status)),
                        if (hasDiscount) ...[
                          const SizedBox(width: 8),
                          const ProductBadge(label: 'Giảm giá'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14213D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.sku ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7893),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price != null ? formatCurrency(price) : '',
                style: const TextStyle(
                  color: Color(0xFF1F67E2),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE8EEF7),
      child: const Icon(Icons.devices, color: Color(0xFF91A0B8)),
    );
  }
}

