import 'package:flutter/material.dart';

import '../models/product_item.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProductItemSummary> _products = const [];
  String? _selectedCategory;

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
      final response = await ApiService.getProductItems(page: 1, size: 50);
      if (!mounted) return;
      setState(() {
        _products = response.data ?? const [];
        _isLoading = false;
        if (_selectedCategory == null && _categoryNames.isNotEmpty) {
          _selectedCategory = _categoryNames.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<String> get _categoryNames {
    final names = <String>{};
    for (final p in _products) {
      final name = p.category?.name;
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names.toList()..sort();
  }

  List<ProductItemSummary> get _filteredProducts {
    if (_selectedCategory == null) return _products;
    return _products
        .where((p) => p.category?.name == _selectedCategory)
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

    final categories = _categoryNames;
    final products = _filteredProducts;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Chọn danh mục',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14213D),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final name = categories[index];
                final count = _products
                    .where((p) => p.category?.name == name)
                    .length;
                final selected = _selectedCategory == name;
                return Material(
                  color: selected ? const Color(0xFFE8F4FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = name),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF1F67E2)
                              : const Color(0xFFE3EAF5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            color: selected
                                ? const Color(0xFF1F67E2)
                                : const Color(0xFF6B7893),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xFF1F67E2)
                                  : const Color(0xFF14213D),
                            ),
                          ),
                          Text(
                            '$count sản phẩm',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7893),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              _selectedCategory != null
                  ? 'Sản phẩm: $_selectedCategory'
                  : 'Sản phẩm',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF14213D),
              ),
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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return _CategoryProductTile(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          summary: product,
                        ),
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
}

class _CategoryProductTile extends StatelessWidget {
  const _CategoryProductTile({required this.product, required this.onTap});

  final ProductItemSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = product.salePrice ?? product.price;

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
                child: product.mainImageUrl != null &&
                        product.mainImageUrl!.isNotEmpty
                    ? Image.network(
                        product.mainImageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                price != null ? '${price.round()}đ' : '',
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
