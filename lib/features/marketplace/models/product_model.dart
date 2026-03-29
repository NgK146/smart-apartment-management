// Model cho Sản phẩm
enum ProductType {
  physical, // Hàng hóa (giao hàng)
  service, // Dịch vụ (đặt lịch)
}

class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final ProductType type;
  final bool isAvailable;
  final int storeId;
  final int productCategoryId;
  final String? storeName;
  final String? categoryName;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.type,
    required this.isAvailable,
    required this.storeId,
    required this.productCategoryId,
    this.storeName,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? json['Type'] ?? 'physical').toString().toLowerCase();
    final productType = typeStr == 'service' ? ProductType.service : ProductType.physical;

    return Product(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      description: json['description'] ?? json['Description'],
      price: (json['price'] ?? json['Price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? json['ImageUrl'],
      type: productType,
      isAvailable: json['isAvailable'] ?? json['IsAvailable'] ?? true,
      storeId: json['storeId'] ?? json['StoreId'] ?? 0,
      productCategoryId: json['productCategoryId'] ?? json['ProductCategoryId'] ?? 0,
      storeName: json['storeName'] ?? json['StoreName'],
      categoryName: json['categoryName'] ?? json['CategoryName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'type': type == ProductType.service ? 'service' : 'physical',
      'isAvailable': isAvailable,
      'storeId': storeId,
      'productCategoryId': productCategoryId,
    };
  }
}

