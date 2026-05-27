import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_item.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';
  String _selectedCategory = 'Tất cả';
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
      final response = await ApiService.getProductItems(page: 1, size: 10);
      if (!response.success) {
        throw Exception(response.message.isNotEmpty
            ? response.message
            : 'Không thể tải danh sách sản phẩm');
      }

      final summaries = response.data ?? const <ProductItemSummary>[];
      final loadedProducts = <_CatalogProduct>[];
      for (var i = 0; i < summaries.length; i++) {
        loadedProducts.add(
          _CatalogProduct(
            summary: summaries[i],
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _products = loadedProducts;
        _selectedCategory = 'Tất cả';
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
    final categories = <String>{};
    for (final product in _products) {
      final categoryName = product.summary.category?.name;
      if (categoryName != null && categoryName.isNotEmpty) {
        categories.add(categoryName);
      }
    }
    return ['Tất cả', ...categories];
  }

  List<_CatalogProduct> get _visibleProducts {
    return _products.where((product) {
      final name = product.summary.name.toLowerCase();
      final brandName = product.summary.brand?.name?.toLowerCase() ?? '';
      final categoryName = product.summary.category?.name?.toLowerCase() ?? '';
      final sku = product.summary.sku?.toLowerCase() ?? '';
      final description = product.summary.description?.toLowerCase() ?? '';
      final queryMatch = _query.isEmpty ||
          name.contains(_query) ||
          brandName.contains(_query) ||
          categoryName.contains(_query) ||
          sku.contains(_query) ||
          description.contains(_query);
      final categoryMatch = _selectedCategory == 'Tất cả' ||
          product.summary.category?.name == _selectedCategory;
      return queryMatch && categoryMatch;
    }).toList();
  }

  Future<void> _onRefresh() {
    return _loadProducts();
  }

  void _openProductDetail(_CatalogProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          summary: product.summary,
          initialDetail: null,
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
                  child: _HeroBanner(onExploreTap: () {
                    if (_visibleProducts.isNotEmpty) {
                      _openProductDetail(_visibleProducts.first);
                    }
                  }),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: _SectionHeader(
                    title: 'Danh mục',
                    actionLabel: 'Xem tất cả',
                    onActionTap: () {
                      setState(() {
                        _selectedCategory = 'Tất cả';
                      });
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
                          setState(() {
                            _selectedCategory = category;
                          });
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = visibleProducts[index];
                        return _ProductCard(
                          product: product,
                          onTap: () => _openProductDetail(product),
                        );
                      },
                      childCount: visibleProducts.length,
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
        _IconActionButton(
          icon: Icons.notifications_none_rounded,
          onTap: () {},
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  const _ProductCard({required this.product, required this.onTap});

  final _CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = product.summary;
    final imageUrl = summary.mainImageUrl;
    final currentPrice = summary.salePrice ?? summary.price;
    final originalPrice = summary.hasSalePrice ? summary.price : null;

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
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Badge(
                      text: summary.status == 'active'
                        ? 'Hot'
                        : (summary.status ?? 'N/A'),
                      backgroundColor: summary.status == 'active'
                        ? const Color(0xFFD63546)
                        : const Color(0xFFB27A00),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 16,
                        color: Color(0xFF4F5C77),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
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
                        _formatCurrency(currentPrice),
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
                        _formatCurrency(originalPrice),
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(
          Icons.memory_rounded,
          size: 54,
          color: Color(0xFF1F67E2),
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
              color: Color(0xFF1F67E2),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
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
