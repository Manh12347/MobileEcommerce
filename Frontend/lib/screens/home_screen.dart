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
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  String _selectedCategory = 'Tất cả';
  List<ProductCategory> _availableCategories = const [];
  List<_CatalogProduct> _products = const [];

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
    });

    try {
      int? selectedCategoryId;
      if (_selectedCategory != 'Tất cả') {
        for (final category in _availableCategories) {
          final categoryName = category.name?.trim();
          if (categoryName == _selectedCategory) {
            selectedCategoryId = category.categoryId;
            break;
          }
        }
      }

      final productFuture = ApiService.getProductItems(
        page: 1,
        size: 10,
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
      final loadedProducts = <_CatalogProduct>[];
      for (var i = 0; i < summaries.length; i++) {
        final summary = summaries[i];
        if (isActiveProductStatus(summary.status)) {
          loadedProducts.add(_CatalogProduct(summary: summary));
        }
      }

      if (!mounted) {
        return;
      }

      final normalizedCategories = <ProductCategory>[];
      if (categoryResponse.success) {
        for (final category in categoryResponse.data ?? const <ProductCategory>[]) {
          final name = category.name?.trim();
          if (name == null || name.isEmpty) {
            continue;
          }
          final status = category.status?.trim().toLowerCase() ?? '';
          if (status.isNotEmpty && !isActiveProductStatus(status)) {
            continue;
          }
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
        _products = loadedProducts;
        _availableCategories = normalizedCategories;
        _selectedCategory = nextSelected;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<String> get _categories {
    return _resolveCategoryNames(
      products: _products,
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
      if (rawName == null) {
        continue;
      }
      final name = rawName.trim();
      if (name.isEmpty) {
        continue;
      }
      names.add(name);
      orderByName[name] = category.categoryId ?? 1 << 30;
    }

    for (final product in products) {
      final rawName = product.summary.category?.name;
      if (rawName == null) {
        continue;
      }
      final name = rawName.trim();
      if (name.isEmpty) {
        continue;
      }
      names.add(name);
      orderByName.putIfAbsent(name, () => 1 << 30);
    }

    final sorted = names.toList()
      ..sort((left, right) {
        final leftOrder = orderByName[left] ?? 1 << 30;
        final rightOrder = orderByName[right] ?? 1 << 30;
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        return left.toLowerCase().compareTo(right.toLowerCase());
      });

    return ['Tất cả', ...sorted];
  }

  List<_CatalogProduct> get _visibleProducts {
    return _products.where((product) {
      final name = product.summary.name.toLowerCase();
      final brandName = product.summary.brand?.name?.toLowerCase() ?? '';
      final categoryName = product.summary.category?.name?.toLowerCase() ?? '';
      final sku = product.summary.sku?.toLowerCase() ?? '';
      final description = product.summary.description?.toLowerCase() ?? '';
      final queryMatch =
          _query.isEmpty ||
          name.contains(_query) ||
          brandName.contains(_query) ||
          categoryName.contains(_query) ||
          sku.contains(_query) ||
          description.contains(_query);
      return queryMatch;
    }).toList();
  }

  Future<void> _onRefresh() {
    return _loadProducts();
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

    if (!mounted) {
      return;
    }

    if (ok) {
      // reload cart state so UI (badges) update
      // ignore: unawaited_futures
      context.read<CartProvider>().loadCart(silent: true);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào giỏ hàng thành công'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Wait a bit for snackbar, then switch to Cart tab
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      // Set the tab index to Cart (index 2)
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

    if (!mounted) {
      return;
    }

    if (ok) {
      // reload cart state so UI (badges) update
      // ignore: unawaited_futures
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
                      if (_visibleProducts.isNotEmpty) {
                        _openProductDetail(_visibleProducts.first);
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
                      setState(() {
                        _selectedCategory = 'Tất cả';
                      });
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
                          if (_selectedCategory == category) {
                            return;
                          }
                          setState(() {
                            _selectedCategory = category;
                          });
                          _loadProducts();
                        },
                        label: Text(category),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF17315D),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: _SectionHeader(
                    title: 'Sản phẩm nổi bật',
                    actionLabel: 'Làm mới',
                    onActionTap: () {
                      _onRefresh();
                    },
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = visibleProducts[index];
                      return _ProductCard(
                        product: product,
                        onTap: () => _openProductDetail(product),
                        onAddToCart: () => _addToCart(product),
                        onBuyNow: () => _buyNow(product),
                      );
                    }, childCount: visibleProducts.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogProduct {
  final ProductItemSummary summary;

  const _CatalogProduct({required this.summary});
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
      height: 220,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final _CatalogProduct product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    final summary = product.summary;
    final imageUrl = summary.mainImageUrl;
    final currentPrice = summary.salePrice ?? summary.price;
    final originalPrice = summary.hasSalePrice ? summary.price : null;
    final isActive = isActiveProductStatus(summary.status);
    final canBuy = isActive;
    final badges = <Widget>[
      if (summary.hasSalePrice)
        const ProductBadge(
          label: 'Giảm giá',
          backgroundColor: Color(0xFFD28A00),
          foregroundColor: Colors.white,
        ),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
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
                    height: 122,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                      gradient: LinearGradient(
                        colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: _ProductImage(url: imageUrl),
                  ),
                  if (badges.isNotEmpty)
                    Positioned(left: 12, top: 12, child: Row(children: badges)),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.sku ?? summary.category?.name ?? 'Sản phẩm',
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
                      const Spacer(),
                      Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: OutlinedButton(
                              onPressed: canBuy ? onAddToCart : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1F67E2),
                                side: const BorderSide(color: Color(0xFF1F67E2)),
                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                minimumSize: const Size(52, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Icon(
                                canBuy
                                    ? Icons.shopping_cart_outlined
                                    : Icons.remove_shopping_cart_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: canBuy ? onBuyNow : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1F67E2),
                                disabledBackgroundColor: const Color(0xFFD9E3F2),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                canBuy ? 'Mua ngay' : 'Hết hàng',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
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
  const _ProductImage({required this.url});

  final String? url;

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
        fit: BoxFit.contain,
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
