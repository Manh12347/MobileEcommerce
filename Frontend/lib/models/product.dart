class Brand {
  final int? brandId;
  final String name;
  final String country;
  final String status;

  const Brand({
    this.brandId,
    required this.name,
    required this.country,
    required this.status,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      brandId: json['brandId'] is int
          ? json['brandId'] as int
          : int.tryParse('${json['brandId'] ?? ''}'),
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class Category {
  final int? categoryId;
  final String name;
  final String status;

  const Category({
    this.categoryId,
    required this.name,
    required this.status,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: json['categoryId'] is int
          ? json['categoryId'] as int
          : int.tryParse('${json['categoryId'] ?? ''}'),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class Product {
  final int? productId;
  final String name;
  final String status;
  final Brand? brand;
  final Category? category;

  const Product({
    this.productId,
    required this.name,
    required this.status,
    this.brand,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final brandJson = json['brand'];
    final categoryJson = json['category'];

    return Product(
      productId: json['productId'] is int
          ? json['productId'] as int
          : int.tryParse('${json['productId'] ?? ''}'),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      brand: brandJson is Map<String, dynamic> ? Brand.fromJson(brandJson) : null,
      category: categoryJson is Map<String, dynamic>
          ? Category.fromJson(categoryJson)
          : null,
    );
  }

  bool get isActive => status.toLowerCase() == 'active';

  String get categoryName => category?.name.isNotEmpty == true ? category!.name : 'Khác';

  String get brandName => brand?.name.isNotEmpty == true ? brand!.name : 'Chưa rõ';

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    return name.toLowerCase().contains(normalized) ||
        brandName.toLowerCase().contains(normalized) ||
        categoryName.toLowerCase().contains(normalized);
  }
}