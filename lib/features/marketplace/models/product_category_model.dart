// Model cho Danh mục sản phẩm của Cửa hàng
class ProductCategory {
  final int id;
  final String name;
  final int storeId;

  ProductCategory({
    required this.id,
    required this.name,
    required this.storeId,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      storeId: json['storeId'] ?? json['StoreId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'storeId': storeId,
    };
  }
}

