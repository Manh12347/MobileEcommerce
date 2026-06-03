import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../utils/format_utils.dart';

import '../models/cart.dart';
import '../models/product_item.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../utils/build_compatibility_checker.dart';
import '../utils/app_globals.dart';
import '../widgets/chat_bubble.dart';

class BuildCompatibilityScreen extends StatefulWidget {
  const BuildCompatibilityScreen({super.key, this.cart});

  final Cart? cart;

  @override
  State<BuildCompatibilityScreen> createState() =>
      _BuildCompatibilityScreenState();
}

class _BuildCompatibilityScreenState extends State<BuildCompatibilityScreen> {
  late Future<_BuildCompatibilityViewData> _future;
  final Map<String, ProductItemSummary> _newSelectedProducts = {};
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _future = _loadInitialData();
  }

  @override
  void dispose() {
    if (ChatbotContext.activeScreen == 'PCBuild') {
      ChatbotContext.activeScreen = 'Home';
    }
    super.dispose();
  }

  Future<_BuildCompatibilityViewData> _loadInitialData() async {
    await _loadSelectedNewProducts();
    if (mounted) {
      setState(() {});
    }
    return _loadBuildData();
  }

  Map<String, dynamic> _productSummaryToMap(ProductItemSummary product) {
    return {
      'productItemId': product.productItemId,
      'productId': product.productId,
      'sku': product.sku,
      'description': product.description,
      'stockQuantity': product.stockQuantity,
      'soldQuantity': product.soldQuantity,
      'status': product.status,
      'price': product.price,
      'salePrice': product.salePrice,
      'mainImageUrl': product.mainImageUrl,
      'productName': product.productName,
      'categoryName': product.category?.name,
    };
  }

  ProductItemSummary _productSummaryFromMap(Map<String, dynamic> map) {
    return ProductItemSummary(
      productItemId: map['productItemId'] as int?,
      productId: map['productId'] as int?,
      sku: map['sku'] as String?,
      description: map['description'] as String?,
      stockQuantity: map['stockQuantity'] as int?,
      soldQuantity: map['soldQuantity'] as int?,
      status: map['status'] as String?,
      price: map['price'] as double?,
      salePrice: map['salePrice'] as double?,
      mainImageUrl: map['mainImageUrl'] as String?,
      productName: map['productName'] as String?,
      category: map['categoryName'] != null
          ? ProductCategory(name: map['categoryName'] as String)
          : null,
    );
  }

  Future<void> _saveSelectedNewProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      _newSelectedProducts.forEach((key, value) {
        data[key] = _productSummaryToMap(value);
      });
      await prefs.setString('build_selected_new_products', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadSelectedNewProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('build_selected_new_products');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        data.forEach((key, value) {
          _newSelectedProducts[key] = _productSummaryFromMap(value as Map<String, dynamic>);
        });
      }
    } catch (_) {}
  }

  Future<void> _exportBuildQuotation() async {
    try {
      final data = await _future;
      if (data.entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ít nhất một linh kiện để xuất cấu hình.')),
        );
        return;
      }
      
      final buffer = StringBuffer();
      buffer.writeln('=== BÁO GIÁ CẤU HÌNH PC TECHSHOP ===');
      double total = 0;
      for (final entry in data.entries) {
        final category = entry.category;
        final name = entry.detail?.productName ?? entry.cartItem.productName ?? 'Chưa chọn';
        final price = entry.detail?.salePrice ?? entry.detail?.price ?? entry.cartItem.price ?? 0.0;
        total += price;
        buffer.writeln('- $category: $name - ${FormatUtils.formatMoney(price)}');
      }
      
      double assemblyFee = total > 15000000 ? 0 : 200000;
      if (assemblyFee > 0) {
        buffer.writeln('- Phí lắp ráp & cài đặt: ${FormatUtils.formatMoney(assemblyFee)}');
        total += assemblyFee;
      } else {
        buffer.writeln('- Phí lắp ráp & cài đặt: Miễn phí (Đơn hàng > 15 triệu)');
      }
      
      buffer.writeln('-----------------------------------');
      buffer.writeln('TỔNG CỘNG: ${FormatUtils.formatMoney(total)}');
      
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép cấu hình PC vào bộ nhớ tạm!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất cấu hình: $e')),
      );
    }
  }

  Future<_BuildCompatibilityViewData> _loadBuildData() async {
    final entries = <_BuildPartEntry>[];
    final loadWarnings = <String>[];

    for (final element in _newSelectedProducts.entries) {
      final category = element.key;
      final product = element.value;
      final id = product.productItemId;
      if (id == null) continue;

      ProductItemDetail? detail;
      Map<String, dynamic> specs = const <String, dynamic>{};

      if (id >= 99901 && id <= 99905) {
        if (id == 99901) {
          specs = {
            "compatibility": {
              "wattage_w": 650,
              "form_factor": "ATX",
              "efficiency": "80 Plus Bronze",
              "power_connectors": [
                {"type": "24-pin", "count": 1},
                {"type": "8-pin CPU", "count": 2},
                {"type": "6+2-pin PCIe", "count": 2},
                {"type": "SATA", "count": 5}
              ]
            }
          };
          detail = ProductItemDetail(
            productItemId: 99901,
            productId: 99901,
            sku: 'PSU-MSI-A650BN',
            productName: 'Nguồn MSI MAG A650BN 650W',
            categoryName: 'PSU',
            price: 1450000,
            serials: const [],
          );
        } else if (id == 99902) {
          specs = {
            "compatibility": {
              "wattage_w": 850,
              "form_factor": "ATX",
              "efficiency": "80 Plus Gold",
              "power_connectors": [
                {"type": "24-pin", "count": 1},
                {"type": "8-pin CPU", "count": 2},
                {"type": "6+2-pin PCIe", "count": 4},
                {"type": "SATA", "count": 7}
              ]
            }
          };
          detail = ProductItemDetail(
            productItemId: 99902,
            productId: 99902,
            sku: 'PSU-CORSAIR-RM850E',
            productName: 'Nguồn Corsair RM850e 850W Gold',
            categoryName: 'PSU',
            price: 2990000,
            serials: const [],
          );
        } else if (id == 99903) {
          specs = {
            "compatibility": {
              "requires_m2_slot": true,
              "form_factor": "M.2 2280",
              "requires_pcie_generation": "Gen 4",
              "capacity_gb": 1000
            }
          };
          detail = ProductItemDetail(
            productItemId: 99903,
            productId: 99903,
            sku: 'SSD-SAMSUNG-990PRO-1TB',
            productName: 'SSD Samsung 990 Pro 1TB M.2 NVMe',
            categoryName: 'SSD/HDD',
            price: 2490000,
            serials: const [],
          );
        } else if (id == 99904) {
          specs = {
            "compatibility": {
              "requires_m2_slot": true,
              "form_factor": "M.2 2280",
              "requires_pcie_generation": "Gen 4",
              "capacity_gb": 500
            }
          };
          detail = ProductItemDetail(
            productItemId: 99904,
            productId: 99904,
            sku: 'SSD-KINGSTON-NV2-500GB',
            productName: 'SSD Kingston NV2 500GB M.2',
            categoryName: 'SSD/HDD',
            price: 990000,
            serials: const [],
          );
        } else if (id == 99905) {
          specs = {
            "compatibility": {
              "requires_sata_port": 1,
              "requires_sata_power": 1,
              "form_factor": "3.5 inch",
              "capacity_gb": 2000
            }
          };
          detail = ProductItemDetail(
            productItemId: 99905,
            productId: 99905,
            sku: 'HDD-SEAGATE-2TB',
            productName: 'HDD Seagate BarraCuda 2TB 3.5"',
            categoryName: 'SSD/HDD',
            price: 1590000,
            serials: const [],
          );
        }
      } else {
        try {
          final response = await ApiService.getProductItemDetail(id);
          if (response.success) {
            detail = response.data;
          }
        } catch (e) {
          loadWarnings.add(
            'Không tải được thông số cho ${product.name}: ${e.toString().replaceAll('Exception: ', '')}',
          );
        }
        specs = detail?.specifications ?? const <String, dynamic>{};
      }

      final cartItem = CartItem(
        cartItemId: -id,
        productItemId: id,
        quantity: 1,
        sku: product.sku,
        productName: product.name,
        mainImageUrl: product.mainImageUrl,
        price: product.price,
        salePrice: product.salePrice,
      );

      final entry = _BuildPartEntry(
        cartItem: cartItem,
        detail: detail,
        category: product.category?.name ?? category,
        specifications: specs,
      );
      entries.add(entry);
    }

    final build = <BuildPart>[];
    for (final entry in entries) {
      build.add(
        BuildPart(
          name: entry.name,
          category: entry.category,
          specifications: entry.specifications,
        ),
      );
    }

    final result = checkBuildCompatibility(build);
    for (final warning in loadWarnings) {
      result.warnings.add(warning);
    }

    final unknownCount = entries
        .where((entry) => normalizeBuildCategory(entry.category) == 'unknown')
        .length;
    if (unknownCount > 0) {
      result.warnings.add(
        '$unknownCount sản phẩm chưa xác định được loại linh kiện nên chưa được tính vào kết quả.',
      );
    }

    return _BuildCompatibilityViewData(entries: entries, result: result);
  }

  Future<List<_CatalogPartEntry>> _loadCatalogSuggestions(
    String category,
  ) async {
    final list = <_CatalogPartEntry>[];
    final normalized = normalizeBuildCategory(category);
    try {
      final response = await ApiService.getProductItems(page: 1, size: 100);
      final products = response.data ?? const <ProductItemSummary>[];
      final items = products
          .where((product) => product.productItemId != null)
          .map(
            (product) => _CatalogPartEntry(
              product: product,
              category: _resolveProductSummaryCategory(product),
            ),
          )
          .where(
            (entry) => normalizeBuildCategory(entry.category) == normalized,
          )
          .toList();
      list.addAll(items);
    } catch (e) {
      debugPrint('Error loading catalog suggestions: $e');
    }

    if (list.isEmpty) {
      if (normalized == 'psu') {
        list.addAll([
          _CatalogPartEntry(
            category: 'PSU',
            product: ProductItemSummary(
              productItemId: 99901,
              productId: 99901,
              sku: 'PSU-MSI-A650BN',
              productName: 'Nguồn MSI MAG A650BN 650W',
              price: 1450000,
              status: 'active',
              stockQuantity: 10,
              mainImageUrl: 'https://doantrang.online/v1/api/uploads/products/msi_mag_a650bn.webp',
              category: ProductCategory(name: 'PSU'),
            ),
          ),
          _CatalogPartEntry(
            category: 'PSU',
            product: ProductItemSummary(
              productItemId: 99902,
              productId: 99902,
              sku: 'PSU-CORSAIR-RM850E',
              productName: 'Nguồn Corsair RM850e 850W Gold',
              price: 2990000,
              status: 'active',
              stockQuantity: 5,
              mainImageUrl: 'https://doantrang.online/v1/api/uploads/products/corsair_rm850e.webp',
              category: ProductCategory(name: 'PSU'),
            ),
          ),
        ]);
      } else if (normalized == 'ssd/hdd') {
        list.addAll([
          _CatalogPartEntry(
            category: 'SSD/HDD',
            product: ProductItemSummary(
              productItemId: 99903,
              productId: 99903,
              sku: 'SSD-SAMSUNG-990PRO-1TB',
              productName: 'SSD Samsung 990 Pro 1TB M.2 NVMe',
              price: 2490000,
              status: 'active',
              stockQuantity: 15,
              mainImageUrl: 'https://doantrang.online/v1/api/uploads/products/samsung_990pro.webp',
              category: ProductCategory(name: 'SSD/HDD'),
            ),
          ),
          _CatalogPartEntry(
            category: 'SSD/HDD',
            product: ProductItemSummary(
              productItemId: 99904,
              productId: 99904,
              sku: 'SSD-KINGSTON-NV2-500GB',
              productName: 'SSD Kingston NV2 500GB M.2',
              price: 990000,
              status: 'active',
              stockQuantity: 20,
              mainImageUrl: 'https://doantrang.online/v1/api/uploads/products/kingston_nv2.webp',
              category: ProductCategory(name: 'SSD/HDD'),
            ),
          ),
          _CatalogPartEntry(
            category: 'SSD/HDD',
            product: ProductItemSummary(
              productItemId: 99905,
              productId: 99905,
              sku: 'HDD-SEAGATE-2TB',
              productName: 'HDD Seagate BarraCuda 2TB 3.5"',
              price: 1590000,
              status: 'active',
              stockQuantity: 8,
              mainImageUrl: 'https://doantrang.online/v1/api/uploads/products/seagate_2tb.webp',
              category: ProductCategory(name: 'SSD/HDD'),
            ),
          ),
        ]);
      }
    }
    return list;
  }

  Future<void> _openRequirementPicker(
    _BuildRequirement requirement,
    List<_BuildPartEntry> entries,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _RequirementPickerSheet(
        requirement: requirement,
        loadNewProducts: () => _loadCatalogSuggestions(requirement.category),
        onAddProduct: (product) async {
          Navigator.pop(context);
          await _selectNewProduct(requirement.category, product);
        },
      ),
    );
  }

  Future<void> _selectNewProduct(String category, ProductItemSummary product) async {
    final normalized = normalizeBuildCategory(category);
    setState(() {
      _newSelectedProducts[normalized] = product;
    });
    await _saveSelectedNewProducts();
    setState(() {
      _future = _loadBuildData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chọn ${product.name} cho $category'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addSelectedNewProductsToCart() async {
    if (_newSelectedProducts.isEmpty) return;

    setState(() {
      _isAddingToCart = true;
    });

    final provider = context.read<CartProvider>();
    int successCount = 0;
    int failCount = 0;

    final productsToAdd = List<ProductItemSummary>.from(_newSelectedProducts.values);

    final cartItems = provider.cart?.items ?? [];
    for (final product in productsToAdd) {
      final id = product.productItemId;
      if (id == null) continue;
      final alreadyInCart = cartItems.any((item) => item.productItemId == id);
      if (alreadyInCart) {
        successCount++;
        continue;
      }
      final added = await provider.addToCart(productItemId: id, quantity: 1);
      if (added) {
        successCount++;
      } else {
        failCount++;
      }
    }

    if (!mounted) return;

    if (successCount > 0) {
      setState(() {
        _newSelectedProducts.clear();
      });
      await _saveSelectedNewProducts();
      await provider.loadCart(silent: true);
    }

    setState(() {
      _isAddingToCart = false;
    });

    if (!mounted) return;

    String message = '';
    if (successCount > 0 && failCount == 0) {
      message = 'Đã thêm thành công $successCount sản phẩm vào Giỏ hàng!';
    } else if (successCount > 0 && failCount > 0) {
      message = 'Đã thêm $successCount sản phẩm. Thất bại $failCount sản phẩm.';
    } else {
      message = provider.errorMessage.isNotEmpty
          ? provider.errorMessage
          : 'Không thêm được sản phẩm vào Giỏ hàng';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: successCount > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );

    setState(() {
      _future = _loadBuildData();
    });
  }

  Future<void> _clearAllSelections() async {
    setState(() {
      _newSelectedProducts.clear();
    });
    await _saveSelectedNewProducts();
    setState(() {
      _future = _loadBuildData();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa tất cả linh kiện đã chọn.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeProductFromCart(int cartItemId) async {
    final provider = context.read<CartProvider>();
    String name = 'Sản phẩm';
    try {
      final data = await _future;
      final entry = data.entries.firstWhere((e) => e.cartItem.cartItemId == cartItemId);
      name = entry.name;
    } catch (_) {}

    if (cartItemId < 0) {
      final idToRemove = -cartItemId;
      setState(() {
        _newSelectedProducts.removeWhere((key, value) => value.productItemId == idToRemove);
      });
      await _saveSelectedNewProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã bỏ chọn sản phẩm: $name')),
      );
      setState(() {
        _future = _loadBuildData();
      });
      return;
    }

    final removed = await provider.removeItem(cartItemId);
    if (!mounted) return;

    final message = removed
        ? 'Đã xóa sản phẩm khỏi Giỏ hàng: $name'
        : provider.errorMessage.isNotEmpty
        ? provider.errorMessage
        : 'Không xóa được sản phẩm khỏi Giỏ hàng';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (removed) {
      await provider.loadCart(silent: true);
      if (!mounted) return;
      setState(() {
        _future = _loadBuildData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatbotContext.activeScreen = 'PCBuild';
    });
    final cartProvider = context.watch<CartProvider>();
    final cartItems = cartProvider.cart?.items ?? [];
    final newProductsCount = _newSelectedProducts.values.where((product) {
      final id = product.productItemId;
      if (id == null) return false;
      return !cartItems.any((item) => item.productItemId == id);
    }).length;

    return Scaffold(
      floatingActionButton: const ChatBubbleButton(),
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Xây dựng cấu hình',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _exportBuildQuotation,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ cấu hình',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _future = _loadBuildData();
              });
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: FutureBuilder<_BuildCompatibilityViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: () {
                setState(() {
                  _future = _loadBuildData();
                });
              },
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            color: const Color(0xFF1F67E2),
            onRefresh: () async {
              setState(() {
                _future = _loadBuildData();
              });
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _RequirementSection(
                  entries: data.entries,
                  onChoose: _openRequirementPicker,
                  onRemoveProduct: _removeProductFromCart,
                ),
                const SizedBox(height: 6),
                _BuildSummaryCard(entries: data.entries),
                const SizedBox(height: 12),
                _MessageSection(
                  title: 'Lỗi cần sửa',
                  emptyText: 'Không có lỗi tương thích.',
                  icon: Icons.error_outline,
                  color: const Color(0xFFDC2626),
                  messages: data.result.errors.map(_vietnameseMessage).toList(),
                ),
                const SizedBox(height: 12),
                _MessageSection(
                  title: 'Cần lưu ý',
                  emptyText: 'Không có cảnh báo.',
                  icon: Icons.warning_amber_outlined,
                  color: const Color(0xFFF59E0B),
                  messages: data.result.warnings
                      .map(_vietnameseMessage)
                      .toList(),
                ),
                const SizedBox(height: 12),
                _MessageSection(
                  title: 'Thông tin',
                  emptyText: 'Chưa có thông tin bổ sung.',
                  icon: Icons.info_outline,
                  color: const Color(0xFF1F67E2),
                  messages: data.result.info.map(_vietnameseMessage).toList(),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _newSelectedProducts.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (newProductsCount > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đã chọn $newProductsCount linh kiện mới',
                                  style: const TextStyle(
                                    color: Color(0xFF14213D),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Lưu tạm thời ở thiết bị',
                                  style: TextStyle(
                                    color: Color(0xFF6B7893),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isAddingToCart ? null : _addSelectedNewProductsToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F67E2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            child: _isAddingToCart
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Thêm $newProductsCount sản phẩm mới'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isAddingToCart ? null : _clearAllSelections,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        child: const Text('Xóa hết cấu hình đã chọn'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BuildCompatibilityViewData {
  const _BuildCompatibilityViewData({
    required this.entries,
    required this.result,
  });

  final List<_BuildPartEntry> entries;
  final BuildCompatibilityResult result;
}

class _CatalogPartEntry {
  const _CatalogPartEntry({required this.product, required this.category});

  final ProductItemSummary product;
  final String category;
}

class _BuildPartEntry {
  const _BuildPartEntry({
    required this.cartItem,
    required this.detail,
    required this.category,
    required this.specifications,
  });

  final CartItem cartItem;
  final ProductItemDetail? detail;
  final String category;
  final Map<String, dynamic> specifications;

  String get name =>
      detail?.productName ?? cartItem.productName ?? cartItem.sku ?? 'Sản phẩm';
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.result});

  final BuildCompatibilityResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.valid
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final icon = result.valid ? Icons.verified_outlined : Icons.report_outlined;
    final title = result.valid ? 'Build hợp lệ' : 'Build chưa hợp lệ';
    final subtitle = result.valid
        ? 'Các linh kiện chính đang tương thích theo thông số hiện có.'
        : 'Có ${result.errors.length} lỗi cần xử lý trước khi mua.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF14213D),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7893),
                    fontSize: 13,
                    height: 1.35,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF14213D),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _BuildRequirement {
  const _BuildRequirement({
    required this.label,
    required this.category,
    required this.required,
    required this.icon,
  });

  final String label;
  final String category;
  final bool required;
  final IconData icon;
}

const _buildRequirements = [
  _BuildRequirement(
    label: 'Mainboard',
    category: 'Mainboard',
    required: true,
    icon: Icons.developer_board_outlined,
  ),
  _BuildRequirement(
    label: 'CPU',
    category: 'CPU',
    required: true,
    icon: Icons.memory_outlined,
  ),
  _BuildRequirement(
    label: 'RAM',
    category: 'RAM',
    required: true,
    icon: Icons.view_module_outlined,
  ),
  _BuildRequirement(
    label: 'SSD/HDD',
    category: 'SSD/HDD',
    required: true,
    icon: Icons.storage_outlined,
  ),
  _BuildRequirement(
    label: 'Nguồn máy tính',
    category: 'PSU',
    required: true,
    icon: Icons.power_outlined,
  ),
  _BuildRequirement(
    label: 'Case',
    category: 'Case',
    required: true,
    icon: Icons.inventory_2_outlined,
  ),
  _BuildRequirement(
    label: 'VGA/Card màn hình',
    category: 'GPU',
    required: false,
    icon: Icons.videogame_asset_outlined,
  ),
  _BuildRequirement(
    label: 'Tản nhiệt CPU',
    category: 'Tan nhiet',
    required: false,
    icon: Icons.ac_unit_outlined,
  ),
];

class _RequirementSection extends StatelessWidget {
  const _RequirementSection({
    required this.entries,
    required this.onChoose,
    required this.onRemoveProduct,
  });

  final List<_BuildPartEntry> entries;
  final Future<void> Function(
    _BuildRequirement requirement,
    List<_BuildPartEntry> entries,
  )
  onChoose;
  final ValueChanged<int> onRemoveProduct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Danh sách linh kiện cần có'),
        const SizedBox(height: 10),
        for (final requirement in _buildRequirements) ...[
          _RequirementCard(
            requirement: requirement,
            selectedEntries: _entriesFor(requirement.category),
            onChoose: () => onChoose(requirement, entries),
            onRemoveProduct: onRemoveProduct,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  List<_BuildPartEntry> _entriesFor(String category) {
    final normalized = normalizeBuildCategory(category);
    return entries
        .where((entry) => normalizeBuildCategory(entry.category) == normalized)
        .toList();
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.requirement,
    required this.selectedEntries,
    required this.onChoose,
    required this.onRemoveProduct,
  });

  final _BuildRequirement requirement;
  final List<_BuildPartEntry> selectedEntries;
  final VoidCallback onChoose;
  final ValueChanged<int> onRemoveProduct;

  @override
  Widget build(BuildContext context) {
    final hasProduct = selectedEntries.isNotEmpty;
    final statusColor = hasProduct
        ? const Color(0xFF16A34A)
        : requirement.required
        ? const Color(0xFFDC2626)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(requirement.icon, color: const Color(0xFF1F67E2)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  requirement.label,
                  style: const TextStyle(
                    color: Color(0xFF14213D),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasProduct)
                _Pill(
                  label: 'Đã có ${selectedEntries.length}',
                  color: statusColor,
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Chọn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F67E2),
                  side: const BorderSide(color: Color(0xFFB9D9FF)),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasProduct)
            for (final entry in selectedEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SelectedBuildProductRow(
                  entry: entry,
                  onRemove: () => onRemoveProduct(entry.cartItem.cartItemId),
                ),
              )
          else ...[
            Text(
              requirement.required
                  ? 'Chưa có linh kiện này trong Giỏ hàng.'
                  : 'Có thể thêm nếu cấu hình cần linh kiện này.',
              style: const TextStyle(color: Color(0xFF6B7893), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.product, required this.onAdd});

  final ProductItemSummary product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Row(
        children: [
          _ProductThumb(imageUrl: product.mainImageUrl, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Chọn'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F67E2),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementPickerSheet extends StatefulWidget {
  const _RequirementPickerSheet({
    required this.requirement,
    required this.loadNewProducts,
    required this.onAddProduct,
  });

  final _BuildRequirement requirement;
  final Future<List<_CatalogPartEntry>> Function() loadNewProducts;
  final Future<void> Function(ProductItemSummary product) onAddProduct;

  @override
  State<_RequirementPickerSheet> createState() =>
      _RequirementPickerSheetState();
}

class _RequirementPickerSheetState extends State<_RequirementPickerSheet> {
  Future<List<_CatalogPartEntry>>? _newProductsFuture;
  Future<List<_BuildPartEntry>>? _cartProductsFuture;

  @override
  void initState() {
    super.initState();
    _newProductsFuture = widget.loadNewProducts();
    _cartProductsFuture = _loadCartItemsOfCategory();
  }

  Future<List<_BuildPartEntry>> _loadCartItemsOfCategory() async {
    final provider = context.read<CartProvider>();
    final cart = provider.cart;
    final categoryNormalized = normalizeBuildCategory(widget.requirement.category);
    final list = <_BuildPartEntry>[];
    if (cart == null) return list;

    for (final item in cart.items) {
      ProductItemDetail? detail;
      try {
        final response = await ApiService.getProductItemDetail(item.productItemId);
        if (response.success) {
          detail = response.data;
        }
      } catch (_) {}

      final specs = detail?.specifications ?? const <String, dynamic>{};
      final category = _resolveBuildCategory(item, detail, specs);
      final normalizedCat = normalizeBuildCategory(category);

      if (normalizedCat == categoryNormalized) {
        list.add(
          _BuildPartEntry(
            cartItem: item,
            detail: detail,
            category: category,
            specifications: specs,
          ),
        );
      }
    }
    return list;
  }

  ProductItemSummary _cartItemToSummary(CartItem item, ProductItemDetail? detail) {
    return ProductItemSummary(
      productItemId: item.productItemId,
      productId: detail?.productId,
      sku: item.sku,
      description: detail?.description,
      stockQuantity: detail?.stockQuantity,
      soldQuantity: 0,
      status: detail?.status,
      price: item.price,
      salePrice: item.salePrice,
      mainImageUrl: item.mainImageUrl ?? detail?.mainImageUrl,
      productName: item.productName ?? detail?.productName,
      category: detail?.categoryName != null
          ? ProductCategory(name: detail!.categoryName!)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Icon(widget.requirement.icon, color: const Color(0xFF1F67E2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chọn ${widget.requirement.label}',
                        style: const TextStyle(
                          color: Color(0xFF14213D),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Color(0xFF1F67E2),
                unselectedLabelColor: Color(0xFF6B7893),
                indicatorColor: Color(0xFF1F67E2),
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                tabs: [
                  Tab(text: 'Chọn sản phẩm từ giỏ hàng'),
                  Tab(text: 'Chọn sản phẩm mới'),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFE3EAF5)),
              Expanded(
                child: TabBarView(
                  children: [
                    FutureBuilder<List<_BuildPartEntry>>(
                      future: _cartProductsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
                          );
                        }
                        final items = snapshot.data ?? const [];
                        if (items.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Không có sản phẩm nào thuộc nhóm này trong Giỏ hàng.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF6B7893)),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            final summary = _cartItemToSummary(entry.cartItem, entry.detail);
                            return _SuggestionTile(
                              product: summary,
                              onAdd: () => widget.onAddProduct(summary),
                            );
                          },
                        );
                      },
                    ),
                    _NewProductPickerList(
                      future: _newProductsFuture,
                      onAddProduct: widget.onAddProduct,
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

class _SelectedBuildProductRow extends StatelessWidget {
  const _SelectedBuildProductRow({
    required this.entry,
    required this.onRemove,
  });

  final _BuildPartEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final imageUrl = entry.detail?.mainImageUrl ?? entry.cartItem.mainImageUrl;
    return Row(
      children: [
        _ProductThumb(imageUrl: imageUrl, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (entry.cartItem.quantity > 1)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'x${entry.cartItem.quantity}',
              style: const TextStyle(
                color: Color(0xFF1F67E2),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.all(6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          tooltip: entry.cartItem.cartItemId < 0 ? 'Bỏ chọn' : 'Xóa khỏi giỏ hàng',
        ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveImageUrl(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: resolvedUrl.isNotEmpty
          ? Image.network(
              resolvedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE8EEF7),
      child: const Icon(Icons.devices, color: Color(0xFF91A0B8), size: 22),
    );
  }
}



class _NewProductPickerList extends StatelessWidget {
  const _NewProductPickerList({
    required this.future,
    required this.onAddProduct,
  });

  final Future<List<_CatalogPartEntry>>? future;
  final Future<void> Function(ProductItemSummary product) onAddProduct;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(
        child: Text(
          'Chuyển sang tab này để tải sản phẩm mới.',
          style: TextStyle(color: Color(0xFF6B7893)),
        ),
      );
    }

    return FutureBuilder<List<_CatalogPartEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
          );
        }

        final products = snapshot.data ?? const <_CatalogPartEntry>[];
        if (products.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không tìm thấy sản phẩm phù hợp.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7893)),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final product = products[index].product;
            return _SuggestionTile(
              product: product,
              onAdd: () => onAddProduct(product),
            );
          },
        );
      },
    );
  }
}

// ignore: unused_element
class _EmptyCartBuildCard extends StatelessWidget {
  const _EmptyCartBuildCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: Color(0xFF91A0B8),
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'Giỏ hàng chưa có linh kiện',
            style: TextStyle(
              color: Color(0xFF14213D),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Bạn có thể chọn sản phẩm gợi ý ở danh sách linh kiện cần có.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7893), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _BuildPartCard extends StatelessWidget {
  const _BuildPartCard({required this.entry});

  final _BuildPartEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasSpecs = entry.specifications.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                entry.cartItem.mainImageUrl != null &&
                    entry.cartItem.mainImageUrl!.isNotEmpty
                ? Image.network(
                    entry.cartItem.mainImageUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
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
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF14213D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (entry.cartItem.quantity > 1) ...[
                      const SizedBox(width: 8),
                      Text(
                        'x${entry.cartItem.quantity}',
                        style: const TextStyle(
                          color: Color(0xFF1F67E2),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: entry.category,
                      color: const Color(0xFF1F67E2),
                    ),
                    _Pill(
                      label: hasSpecs ? 'Co thong so' : 'Thieu thong so',
                      color: hasSpecs
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 58,
      height: 58,
      color: const Color(0xFFE8EEF7),
      child: const Icon(Icons.memory_outlined, color: Color(0xFF91A0B8)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageSection extends StatelessWidget {
  const _MessageSection({
    required this.title,
    required this.emptyText,
    required this.icon,
    required this.color,
    required this.messages,
  });

  final String title;
  final String emptyText;
  final IconData icon;
  final Color color;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages.isEmpty ? [emptyText] : messages;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF14213D),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${messages.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final message in visibleMessages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: messages.isEmpty ? const Color(0xFFB8C4DA) : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: messages.isEmpty
                            ? const Color(0xFF6B7893)
                            : const Color(0xFF334155),
                        fontSize: 13,
                        height: 1.35,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7893)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }
}

String _resolveBuildCategory(
  CartItem item,
  ProductItemDetail? detail,
  Map<String, dynamic> specs,
) {
  if (detail?.categoryName != null && detail!.categoryName!.isNotEmpty) {
    return _canonicalCategory(detail.categoryName!);
  }

  final explicit = _firstText([
    _nested(specs, 'compatibility.category'),
    _nested(specs, 'category'),
    _nested(specs, 'category_name'),
    _nested(specs, 'categoryName'),
  ]);
  if (explicit != null && explicit.isNotEmpty) {
    return _canonicalCategory(explicit);
  }

  final haystack = normalizeBuildCategory(
    [
      item.productName,
      item.sku,
      detail?.productName,
      detail?.description,
      specs.toString(),
    ].whereType<String>().join(' '),
  );

  if (_containsAny(haystack, [
    'mainboard',
    'motherboard',
    'bo mach chu',
    'h610',
    'b660',
    'b760',
    'z690',
    'z790',
    'a520',
    'b550',
    'b650',
    'x570',
    'x670',
  ])) {
    return 'Mainboard';
  }
  if (_containsAny(haystack, ['cpu', 'processor', 'intel core', 'ryzen'])) {
    return 'CPU';
  }
  if (_containsAny(haystack, ['ram', 'ddr3', 'ddr4', 'ddr5', 'memory'])) {
    return 'RAM';
  }
  if (_containsAny(haystack, [
    'gpu',
    'vga',
    'card man hinh',
    'geforce',
    'radeon',
    'rtx',
    'gtx',
    'rx ',
  ])) {
    return 'GPU';
  }
  if (_containsAny(haystack, ['psu', 'nguon', 'power supply'])) {
    return 'PSU';
  }
  if (_containsAny(haystack, ['case', 'thung may', 'vo may'])) {
    return 'Case';
  }
  if (_containsAny(haystack, ['tan nhiet', 'cooler', 'aio', 'radiator'])) {
    return 'Tan nhiet';
  }
  if (_containsAny(haystack, ['ssd', 'hdd', 'nvme', 'm.2', 'sata'])) {
    return 'SSD/HDD';
  }

  return 'Unknown';
}

String _resolveProductSummaryCategory(ProductItemSummary product) {
  final explicit = product.category?.name;
  if (explicit != null && explicit.trim().isNotEmpty) {
    final canonical = _canonicalCategory(explicit);
    if (_knownBuildCategory(canonical)) {
      return canonical;
    }
  }

  final haystack = normalizeBuildCategory(
    [
      product.productName,
      product.sku,
      product.description,
      product.category?.name,
      product.brand?.name,
    ].whereType<String>().join(' '),
  );

  if (_containsAny(haystack, [
    'mainboard',
    'motherboard',
    'bo mach chu',
    'h610',
    'b660',
    'b760',
    'z690',
    'z790',
    'a520',
    'b550',
    'b650',
    'x570',
    'x670',
  ])) {
    return 'Mainboard';
  }
  if (_containsAny(haystack, ['cpu', 'processor', 'intel core', 'ryzen'])) {
    return 'CPU';
  }
  if (_containsAny(haystack, ['ram', 'ddr3', 'ddr4', 'ddr5', 'memory'])) {
    return 'RAM';
  }
  if (_containsAny(haystack, [
    'gpu',
    'vga',
    'card man hinh',
    'geforce',
    'radeon',
    'rtx',
    'gtx',
    'rx ',
  ])) {
    return 'GPU';
  }
  if (_containsAny(haystack, ['psu', 'nguon', 'power supply'])) {
    return 'PSU';
  }
  if (_containsAny(haystack, ['case', 'thung may', 'vo may'])) {
    return 'Case';
  }
  if (_containsAny(haystack, ['tan nhiet', 'cooler', 'aio', 'radiator'])) {
    return 'Tan nhiet';
  }
  if (_containsAny(haystack, ['ssd', 'hdd', 'nvme', 'm.2', 'sata'])) {
    return 'SSD/HDD';
  }

  return 'Unknown';
}

bool _knownBuildCategory(String category) {
  const known = {
    'mainboard',
    'cpu',
    'ram',
    'ssd/hdd',
    'gpu',
    'psu',
    'case',
    'tan nhiet',
  };
  return known.contains(normalizeBuildCategory(category));
}

String _vietnameseMessage(String message) {
  return message;
}

String _canonicalCategory(String value) {
  final normalized = normalizeBuildCategory(value);
  if (normalized.contains('mainboard') ||
      normalized.contains('motherboard') ||
      normalized.contains('bo mach chu')) {
    return 'Mainboard';
  }
  if (normalized.contains('cpu') || normalized.contains('processor')) {
    return 'CPU';
  }
  if (normalized.contains('ram') || normalized.contains('memory')) {
    return 'RAM';
  }
  if (normalized.contains('gpu') ||
      normalized.contains('vga') ||
      normalized.contains('card man hinh')) {
    return 'GPU';
  }
  if (normalized.contains('psu') || normalized.contains('nguon')) {
    return 'PSU';
  }
  if (normalized.contains('case') || normalized.contains('thung may')) {
    return 'Case';
  }
  if (normalized.contains('tan nhiet') || normalized.contains('cooler')) {
    return 'Tan nhiet';
  }
  if (normalized.contains('ssd') || normalized.contains('hdd')) {
    return 'SSD/HDD';
  }
  return value;
}

String _resolveImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) {
    return 'https://doantrang.online$trimmed';
  }
  return 'https://doantrang.online/$trimmed';
}

bool _containsAny(String source, List<String> needles) {
  return needles.any((needle) => source.contains(needle));
}

String? _firstText(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

Object? _nested(Map<String, dynamic> obj, String path) {
  Object? current = obj;
  for (final key in path.split('.')) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

class _BuildSummaryCard extends StatelessWidget {
  const _BuildSummaryCard({required this.entries});

  final List<_BuildPartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    double totalComponents = 0;
    for (final entry in entries) {
      final price = entry.detail?.salePrice ?? entry.detail?.price ?? entry.cartItem.price ?? 0.0;
      totalComponents += price;
    }

    double assemblyFee = totalComponents > 15000000 ? 0 : 200000;
    double grandTotal = totalComponents + assemblyFee;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt chi phí',
            style: TextStyle(
              color: Color(0xFF14213D),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              const Text(
                'Tổng tiền linh kiện:',
                style: TextStyle(color: Color(0xFF6B7893), fontSize: 14),
              ),
              Text(
                FormatUtils.formatMoney(totalComponents),
                style: const TextStyle(
                  color: Color(0xFF14213D),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              const Text(
                'Phí lắp ráp & cài đặt:',
                style: TextStyle(color: Color(0xFF6B7893), fontSize: 14),
              ),
              Text(
                assemblyFee > 0 ? FormatUtils.formatMoney(assemblyFee) : 'Miễn phí',
                style: TextStyle(
                  color: assemblyFee > 0 ? const Color(0xFF14213D) : const Color(0xFF16A34A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (assemblyFee == 0) ...[
            const SizedBox(height: 4),
            const Text(
              '(*) Miễn phí lắp ráp cho đơn hàng trên 15 triệu VNĐ',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Divider(height: 24, color: Color(0xFFE3EAF5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              const Text(
                'Tổng cộng:',
                style: TextStyle(
                  color: Color(0xFF14213D),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                FormatUtils.formatMoney(grandTotal),
                style: const TextStyle(
                  color: Color(0xFF1F67E2),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
