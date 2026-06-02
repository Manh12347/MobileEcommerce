import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';
import '../utils/app_globals.dart';
import '../utils/format_utils.dart';
import '../widgets/product_badge.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 16;

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  String _selectedCategory = 'Tất cả';
  List<ProductCategory> _availableCategories = const [];
  List<_CatalogProduct> _allProducts = const [];

  // Paginated products
  List<_CatalogProduct> _pagedProducts = const [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = true;
      _pagedProducts = const [];
    });

    try {
      int? selectedCategoryId;
      if (_selectedCategory != 'Tất cả') {
        for (final category in _availableCategories) {
          if (category.name?.trim() == _selectedCategory) {
            selectedCategoryId = category.categoryId;
            break;
          }
        }
      }

      final productFuture = ApiService.getProductItems(
        page: 1,
        size: 200,
        categoryId: selectedCategoryId,
        sortBy: 'newest',
        sortDir: 'desc',
      );
      final categoryFuture = ApiService.getCategories();

      final response = await productFuture;
      final categoryResponse = await categoryFuture;

      if (!response.success) {
        throw Exception(
          response.message.isNotEmpty
              ? response.message
              : 'Không thể tải danh sách sản phẩm',
        );
      }

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

      // Prefetch first variant for only the first 16 products, in parallel
      await Future.wait(loadedProducts.take(_pageSize).map((p) async {
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

      final normalizedCategories = <ProductCategory>[];
      if (categoryResponse.success) {
        for (final category in categoryResponse.data ?? const <ProductCategory>[]) {
          final name = category.name?.trim();
          if (name == null || name.isEmpty) continue;
          final status = category.status?.trim().toLowerCase() ?? '';
          if (status.isNotEmpty && !isActiveProductStatus(status)) continue;
          normalizedCategories.add(
            ProductCategory(
              categoryId: category.categoryId,
              name: name,
              status: category.status,
            ),
          );
        }
      }

      final nextCategories = _resolveCategoryNames(
        products: loadedProducts,
        categories: normalizedCategories,
      );
      final nextSelected =
          nextCategories.contains(_selectedCategory) ? _selectedCategory : 'Tất cả';

      setState(() {
        _allProducts = loadedProducts;
        _availableCategories = normalizedCategories;
        _selectedCategory = nextSelected;
        _pagedProducts = loadedProducts.take(_pageSize).toList();
        _hasMore = loadedProducts.length > _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    final start = _currentPage * _pageSize;
    final end = nextPage * _pageSize;
    final nextProducts = _allProducts.skip(start).take(_pageSize).toList();
    setState(() {
      _pagedProducts = [..._pagedProducts, ...nextProducts];
      _currentPage = nextPage;
      _hasMore = _pagedProducts.length < _allProducts.length;
      _isLoadingMore = false;
    });
  }

  List<String> get _categories {
    return _resolveCategoryNames(
      products: _allProducts,
      categories: _availableCategories,
    );
  }

  List<String> _resolveCategoryNames({
    required List<_CatalogProduct> products,
    required List<ProductCategory> categories,
  }) {
    final orderByName = <String, int>{};
    final names = <String>{};

    for (final category in categories) {
      final rawName = category.name;
      if (rawName == null) continue;
      final name = rawName.trim();
      if (name.isEmpty) continue;
      names.add(name);
      orderByName[name] = category.categoryId ?? 1 << 30;
    }

    for (final product in products) {
      final rawName = product.summary.category?.name;
      if (rawName == null) continue;
      final name = rawName.trim();
      if (name.isEmpty) continue;
      names.add(name);
      orderByName.putIfAbsent(name, () => 1 << 30);
    }

    final sorted = names.toList()
      ..sort((left, right) {
        final leftOrder = orderByName[left] ?? 1 << 30;
        final rightOrder = orderByName[right] ?? 1 << 30;
        if (leftOrder != rightOrder) return leftOrder.compareTo(rightOrder);
        return left.toLowerCase().compareTo(right.toLowerCase());
      });

    return ['Tất cả', ...sorted];
  }

  List<_CatalogProduct> get _visibleProducts {
    return _pagedProducts.where((product) {
      if (_query.isEmpty) return true;
      final name = product.summary.name.toLowerCase();
      final brandName = product.summary.brand?.name?.toLowerCase() ?? '';
      final categoryName = product.summary.category?.name?.toLowerCase() ?? '';
      final sku = product.summary.sku?.toLowerCase() ?? '';
      final description = product.summary.description?.toLowerCase() ?? '';
      return name.contains(_query) ||
          brandName.contains(_query) ||
          categoryName.contains(_query) ||
          sku.contains(_query) ||
          description.contains(_query);
    }).toList();
  }

  // Discounted products sorted newest-first
  List<_CatalogProduct> get _discountedProducts {
    return _allProducts.where((p) {
      final hasDiscount = p.firstVariant?.hasSalePrice == true ||
          (p.firstVariant == null && p.summary.hasSalePrice);
      if (!hasDiscount) return false;
      if (_query.isEmpty) return true;
      final name = p.summary.name.toLowerCase();
      final brandName = p.summary.brand?.name?.toLowerCase() ?? '';
      final sku = p.summary.sku?.toLowerCase() ?? '';
      return name.contains(_query) ||
          brandName.contains(_query) ||
          sku.contains(_query);
    }).toList();
  }

  Future<void> _onRefresh() => _loadProducts();

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
    final productItemId = summary.id;

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
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      navigateToTabNotifier.value = 2;
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

  Future<void> _addToCart(_CatalogProduct product) async {
    final summary = product.summary;
    final productItemId = summary.id;

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

  @override
  Widget build(BuildContext context) {
    final loginResponse = context.watch<LoginProvider>().loginResponse;
    final displayName = loginResponse?.email ?? 'Customer';
    final visibleProducts = _visibleProducts;
    final discountedProducts = _discountedProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF1F67E2),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _TopBar(name: displayName),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _HeroBanner(
                    onExploreTap: () {
                      if (visibleProducts.isNotEmpty) {
                        _openProductDetail(visibleProducts.first);
                      }
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: _SectionHeader(
                    title: 'Danh mục',
                    actionLabel: 'Xem tất cả',
                    onActionTap: () {
                      if (_selectedCategory == 'Tất cả') return;
                      setState(() => _selectedCategory = 'Tất cả');
                      _loadProducts();
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final selected = _selectedCategory == category;
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) {
                          if (_selectedCategory == category) return;
                          setState(() => _selectedCategory = category);
                          _loadProducts();
                        },
                        label: Text(category),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF17315D),
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: const Color(0xFF1F67E2),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected ? const Color(0xFF1F67E2) : const Color(0xFFD8E3F3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // ── Section: Giảm giá ──
              if (_isLoading)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (discountedProducts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD28A00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '🔥 Giảm giá',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${discountedProducts.length} sản phẩm',
                          style: const TextStyle(
                            color: Color(0xFF6B7893),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: discountedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final p = discountedProducts[index];
                        return SizedBox(
                          width: 155,
                          child: _DiscountCard(
                            product: p,
                            onTap: () => _openProductDetail(p),
                            onAddToCart: () => _addToCart(p),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox.shrink()),
              // ── Section: Sản phẩm ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _query.isEmpty ? 'Tất cả sản phẩm' : 'Kết quả tìm kiếm',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF14213D),
                        ),
                      ),
                      Text(
                        '${visibleProducts.length} sản phẩm',
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
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1F67E2),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 54,
                            color: Color(0xFF7A8499),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF273246),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadProducts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F67E2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (visibleProducts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Không có sản phẩm phù hợp',
                      style: TextStyle(
                        color: Color(0xFF5F6B82),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else ...[
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
                        final product = visibleProducts[index];
                        return _ProductCard(
                          product: product,
                          uiScale: scale,
                          onTap: () => _openProductDetail(product),
                          onAddToCart: () => _addToCart(product),
                          onBuyNow: () => _buyNow(product),
                        );
                      }, childCount: visibleProducts.length),
                    );
                  }),
                ),
                // Load more button
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
                  )
                else if (visibleProducts.isNotEmpty)
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogProduct {
  final ProductItemSummary summary;
  ProductItemVariantSummary? firstVariant;

  _CatalogProduct({required this.summary, this.firstVariant});
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F67E2), Color(0xFF60C7FF)],
            ),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/branding/techshop_premium_logo.png',
            height: 26,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TechShop',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14213D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Xin chào, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7893),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _IconActionButton(icon: Icons.notifications_none_rounded, onTap: () {}),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: const Color(0xFF3C4A67)),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EAF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3A7A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Tìm CPU, VGA, Laptop...',
          prefixIcon: Icon(Icons.search_rounded),
          suffixIcon: Icon(Icons.qr_code_scanner_rounded),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onExploreTap});

  final VoidCallback onExploreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10284F), Color(0xFF1F67E2), Color(0xFF4FB3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F67E2).withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -10,
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/branding/techshop_robot.png',
                height: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Tech Gadgets 2026',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 220,
                  child: Text(
                    'Build PC đỉnh cao cùng TechShop',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Giảm ngay 10% khi build trọn bộ',
                  style: TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: TextButton(
                    onPressed: onExploreTap,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F67E2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Khám phá ngay',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF14213D),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1F67E2),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
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
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  @override
  Widget build(BuildContext context) {
    final summary = widget.product.summary;
    final variant = widget.product.firstVariant;
    final variantImage = variant?.mainImageUrl ?? (variant?.images.isNotEmpty == true ? variant!.images.first : null);
    final imageUrl = variantImage ?? summary.mainImageUrl;
    final currentPrice = variant?.salePrice ?? variant?.price ?? summary.salePrice ?? summary.price;
    final originalPrice = variant?.hasSalePrice == true
        ? variant!.price
        : (summary.hasSalePrice ? summary.price : null);
    final isActive = isActiveProductStatus(variant?.status ?? summary.status);
    final canBuy = isActive;
    final badges = <Widget>[
      if ((variant?.hasSalePrice == true) || (variant == null && summary.hasSalePrice))
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
                    child: Padding(
                      padding: EdgeInsets.all(8 * scale),
                      child: _ProductImage(url: imageUrl, fit: BoxFit.contain),
                    ),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, this.fit = BoxFit.contain});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(Icons.memory_rounded, size: 54, color: Color(0xFF1F67E2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
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

class _DiscountCard extends StatelessWidget {
  const _DiscountCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  final _CatalogProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final summary = product.summary;
    final variant = product.firstVariant;
    final imageUrl =
        variant?.mainImageUrl ??
        (variant?.images.isNotEmpty == true ? variant!.images.first : null) ??
        summary.mainImageUrl;
    final currentPrice =
        variant?.salePrice ?? variant?.price ?? summary.salePrice ?? summary.price;
    final originalPrice = variant?.hasSalePrice == true
        ? variant!.price
        : (summary.hasSalePrice ? summary.price : null);
    final discountPct = (originalPrice != null && currentPrice != null && originalPrice > 0)
        ? (((originalPrice - currentPrice) / originalPrice) * 100).round()
        : 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5ECF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _ProductImage(url: imageUrl),
                      ),
                    ),
                    if (discountPct > 0)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD28A00),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-$discountPct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14213D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (currentPrice != null)
                      Text(
                        formatCurrency(currentPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD28A00),
                        ),
                      ),
                    if (originalPrice != null)
                      Text(
                        formatCurrency(originalPrice),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF91A0B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: OutlinedButton(
                        onPressed: onAddToCart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD28A00),
                          side: const BorderSide(color: Color(0xFFD28A00)),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.fromHeight(26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Mua',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
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
