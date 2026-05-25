import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String? accessToken;

  const HomeScreen({super.key, this.accessToken});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<Product>>? _productsFuture;
  List<Product> _products = const [];
  String _query = '';
  String _selectedCategory = 'Tất cả';
  int _currentIndex = 0;

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
      _productsFuture = ApiService.getProducts(accessToken: widget.accessToken);
    });

    try {
      final products = await _productsFuture!;
      if (!mounted) return;
      setState(() {
        _products = products.where((product) => product.isActive).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const [];
      });
    }
  }

  List<String> get _categories {
    final categories = _products
        .map((product) => product.categoryName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return ['Tất cả', ...categories];
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final categoryMatch = _selectedCategory == 'Tất cả' ||
          product.categoryName == _selectedCategory;
      final queryMatch = product.matchesQuery(_query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'TechShop',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thông báo đang được hoàn thiện')),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tài khoản đang được đồng bộ')),
              );
            },
            icon: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            searchController: _searchController,
            onQueryChanged: (value) => setState(() => _query = value),
            selectedCategory: _selectedCategory,
            categories: _categories,
            onSelectCategory: (category) {
              setState(() => _selectedCategory = category);
            },
            productsFuture: _productsFuture,
            filteredProducts: _filteredProducts,
            onRetry: _loadProducts,
            onProductTap: _openProductDetail,
          ),
          _CategoriesTab(
            categories: _categories,
            products: _products,
            onTapCategory: (category) {
              setState(() {
                _selectedCategory = category;
                _currentIndex = 0;
              });
            },
          ),
          const _PlaceholderTab(
            title: 'Giỏ hàng',
            subtitle: 'Chức năng giỏ hàng sẽ được nối API ở bước tiếp theo.',
            icon: Icons.shopping_cart_outlined,
          ),
          const _PlaceholderTab(
            title: 'Đơn hàng',
            subtitle: 'Danh sách đơn hàng sẽ hiển thị ở đây khi BE sẵn sàng.',
            icon: Icons.receipt_long_outlined,
          ),
          const _PlaceholderTab(
            title: 'Cá nhân',
            subtitle: 'Trang hồ sơ cá nhân sẽ được hoàn thiện sau.',
            icon: Icons.person_outline_rounded,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Danh mục',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Giỏ hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }

  void _openProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onSelectCategory;
  final Future<List<Product>>? productsFuture;
  final List<Product> filteredProducts;
  final Future<void> Function() onRetry;
  final ValueChanged<Product> onProductTap;

  const _HomeTab({
    required this.searchController,
    required this.onQueryChanged,
    required this.selectedCategory,
    required this.categories,
    required this.onSelectCategory,
    required this.productsFuture,
    required this.filteredProducts,
    required this.onRetry,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                  ),
                  const SizedBox(height: 16),
                  _HeroBanner(
                    title: 'Build PC Đỉnh Cao',
                    subtitle: 'Khám phá sản phẩm mới, cập nhật nhanh từ BE.',
                    onTap: onRetry,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Danh mục',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => onSelectCategory('Tất cả'),
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = selectedCategory == category;
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text(category),
                          onSelected: (_) => onSelectCategory(category),
                          selectedColor: const Color(0xFFDCEBFF),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF0D47A1) : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: categories.length,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sản phẩm nổi bật',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: FutureBuilder<List<Product>>(
              future: productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    filteredProducts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError && filteredProducts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 320,
                      child: _EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Không tải được sản phẩm',
                        subtitle: snapshot.error.toString(),
                        actionLabel: 'Thử lại',
                        onAction: onRetry,
                      ),
                    ),
                  );
                }

                if (filteredProducts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 320,
                      child: _EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'Không có sản phẩm phù hợp',
                        subtitle: 'Thử đổi từ khóa hoặc danh mục khác.',
                      ),
                    ),
                  );
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 250,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = filteredProducts[index];
                      return _ProductCard(
                        product: product,
                        onTap: () => onProductTap(product),
                      );
                    },
                    childCount: filteredProducts.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Tìm CPU, VGA, Laptop...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            onPressed: () {
              controller.clear();
              onChanged('');
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HeroBanner({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Chip(
                    label: Text('Mở rộng ngay'),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.electrical_services_rounded,
              size: 74,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _paletteForCategory(product.categoryName),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      _iconForCategory(product.categoryName),
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _StatusBadge(status: product.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                product.categoryName,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.brandName,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    product.isActive ? Icons.check_circle : Icons.info_outline,
                    color: product.isActive ? const Color(0xFF2E7D32) : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product.isActive ? 'Còn hàng' : 'Không khả dụng',
                    style: TextStyle(
                      color: product.isActive ? const Color(0xFF2E7D32) : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('cpu')) return Icons.memory_rounded;
    if (normalized.contains('gpu') || normalized.contains('vga')) return Icons.videogame_asset_rounded;
    if (normalized.contains('ram')) return Icons.storage_rounded;
    if (normalized.contains('mainboard')) return Icons.settings_input_component_rounded;
    if (normalized.contains('laptop')) return Icons.laptop_mac_rounded;
    if (normalized.contains('điện thoại') || normalized.contains('phone')) return Icons.phone_iphone_rounded;
    return Icons.devices_rounded;
  }

  List<Color> _paletteForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('cpu')) {
      return const [Color(0xFF0D47A1), Color(0xFF42A5F5)];
    }
    if (normalized.contains('gpu') || normalized.contains('vga')) {
      return const [Color(0xFF263238), Color(0xFF607D8B)];
    }
    if (normalized.contains('ram')) {
      return const [Color(0xFF6A1B9A), Color(0xFFBA68C8)];
    }
    if (normalized.contains('mainboard')) {
      return const [Color(0xFF004D40), Color(0xFF26A69A)];
    }
    if (normalized.contains('laptop')) {
      return const [Color(0xFF1B5E20), Color(0xFF66BB6A)];
    }
    return const [Color(0xFF1565C0), Color(0xFF64B5F6)];
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final isActive = normalized == 'active';
    final background = isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final foreground = isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Mới' : status,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: _paletteForCategory(product.categoryName),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  _iconForCategory(product.categoryName),
                  size: 120,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                product.categoryName,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(label: 'Brand', value: product.brandName),
                  _InfoChip(label: 'Country', value: product.brand?.country.isNotEmpty == true ? product.brand!.country : 'Chưa rõ'),
                  _InfoChip(label: 'Status', value: product.status),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Mô tả',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dữ liệu BE hiện chỉ trả về tên, thương hiệu, danh mục và trạng thái. Trang chi tiết này đang hiển thị đúng dữ liệu thật từ API; khi BE bổ sung giá, mô tả hoặc ảnh, giao diện có thể mở rộng tiếp mà không cần đổi luồng điều hướng.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng đặt hàng sẽ nối sau')),
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Mua ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('cpu')) return Icons.memory_rounded;
    if (normalized.contains('gpu') || normalized.contains('vga')) return Icons.videogame_asset_rounded;
    if (normalized.contains('ram')) return Icons.storage_rounded;
    if (normalized.contains('mainboard')) return Icons.settings_input_component_rounded;
    if (normalized.contains('laptop')) return Icons.laptop_mac_rounded;
    if (normalized.contains('điện thoại') || normalized.contains('phone')) return Icons.phone_iphone_rounded;
    return Icons.devices_rounded;
  }

  List<Color> _paletteForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('cpu')) {
      return const [Color(0xFF0D47A1), Color(0xFF42A5F5)];
    }
    if (normalized.contains('gpu') || normalized.contains('vga')) {
      return const [Color(0xFF263238), Color(0xFF607D8B)];
    }
    if (normalized.contains('ram')) {
      return const [Color(0xFF6A1B9A), Color(0xFFBA68C8)];
    }
    if (normalized.contains('mainboard')) {
      return const [Color(0xFF004D40), Color(0xFF26A69A)];
    }
    if (normalized.contains('laptop')) {
      return const [Color(0xFF1B5E20), Color(0xFF66BB6A)];
    }
    return const [Color(0xFF1565C0), Color(0xFF64B5F6)];
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  final List<String> categories;
  final List<Product> products;
  final ValueChanged<String> onTapCategory;

  const _CategoriesTab({
    required this.categories,
    required this.products,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Danh mục sản phẩm',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn danh mục để lọc nhanh các sản phẩm đang có trong BE.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) {
          final count = category == 'Tất cả'
              ? products.length
              : products.where((product) => product.categoryName == category).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDCEBFF),
                child: Text(count.toString()),
              ),
              title: Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('$count sản phẩm'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTapCategory(category),
            ),
          );
        }),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 68, color: const Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 68, color: const Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}