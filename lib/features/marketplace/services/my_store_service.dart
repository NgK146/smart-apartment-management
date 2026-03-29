// Service cho My Store (người bán)
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/store_model.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/store_review_model.dart';

class MyStoreService {
  final Dio _dio = api.dio;

  // GET /api/my-store: Lấy thông tin Store của mình
  Future<Store> getMyStore() async {
    final res = await _dio.get('/api/my-store');
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/my-store: Cập nhật Store
  Future<Store> updateStore({
    String? name,
    String? description,
    String? phone,
    String? logoUrl,
    String? coverImageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (phone != null) data['phone'] = phone;
    if (logoUrl != null) data['logoUrl'] = logoUrl;
    if (coverImageUrl != null) data['coverImageUrl'] = coverImageUrl;

    final res = await _dio.put(
      '/api/my-store',
      data: data,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // POST /api/my-store/register: Đăng ký trở thành người bán
  Future<Store> registerStore({
    required String name,
    required String phone,
    String? description,
  }) async {
    final res = await _dio.post(
      '/api/my-store/register',
      data: {
        'name': name,
        'phone': phone,
        if (description != null && description.isNotEmpty) 'description': description,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // === QUẢN LÝ DANH MỤC ===

  // GET /api/my-store/categories
  Future<List<ProductCategory>> getCategories() async {
    final res = await _dio.get('/api/my-store/categories');
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // POST /api/my-store/categories
  Future<ProductCategory> createCategory(String name) async {
    final res = await _dio.post(
      '/api/my-store/categories',
      data: {'name': name},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return ProductCategory.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/my-store/categories/{id}
  Future<ProductCategory> updateCategory(int categoryId, String name) async {
    final res = await _dio.put(
      '/api/my-store/categories/$categoryId',
      data: {'name': name},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return ProductCategory.fromJson(Map<String, dynamic>.from(res.data));
  }

  // DELETE /api/my-store/categories/{id}
  Future<void> deleteCategory(int categoryId) async {
    await _dio.delete('/api/my-store/categories/$categoryId');
  }

  // === QUẢN LÝ SẢN PHẨM ===

  // GET /api/my-store/products
  Future<List<Product>> getProducts({String? search, int? categoryId}) async {
    final res = await _dio.get('/api/my-store/products', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': categoryId,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // POST /api/my-store/products
  Future<Product> createProduct({
    required String name,
    required double price,
    required int productCategoryId,
    String? description,
    String? imageUrl,
    ProductType type = ProductType.physical,
    bool isAvailable = true,
  }) async {
    final res = await _dio.post(
      '/api/my-store/products',
      data: {
        'name': name,
        'price': price,
        'productCategoryId': productCategoryId,
        if (description != null && description.isNotEmpty) 'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'type': type == ProductType.service ? 'service' : 'physical',
        'isAvailable': isAvailable,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return Product.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/my-store/products/{id}
  Future<Product> updateProduct({
    required int productId,
    String? name,
    double? price,
    int? productCategoryId,
    String? description,
    String? imageUrl,
    ProductType? type,
    bool? isAvailable,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (price != null) data['price'] = price;
    if (productCategoryId != null) data['productCategoryId'] = productCategoryId;
    if (description != null) data['description'] = description;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (type != null) data['type'] = type == ProductType.service ? 'service' : 'physical';
    if (isAvailable != null) data['isAvailable'] = isAvailable;

    final res = await _dio.put(
      '/api/my-store/products/$productId',
      data: data,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return Product.fromJson(Map<String, dynamic>.from(res.data));
  }

  // DELETE /api/my-store/products/{id}
  Future<void> deleteProduct(int productId) async {
    await _dio.delete('/api/my-store/products/$productId');
  }

  // === QUẢN LÝ ĐƠN HÀNG ===

  // GET /api/my-store/orders
  Future<List<Order>> getOrders({OrderStatus? status}) async {
    String? statusStr;
    if (status != null) {
      switch (status) {
        case OrderStatus.confirmed:
          statusStr = 'confirmed';
          break;
        case OrderStatus.delivering:
          statusStr = 'delivering';
          break;
        case OrderStatus.completed:
          statusStr = 'completed';
          break;
        case OrderStatus.cancelled:
          statusStr = 'cancelled';
          break;
        default:
          statusStr = 'pending';
      }
    }

    final res = await _dio.get('/api/my-store/orders', queryParameters: {
      if (statusStr != null) 'status': statusStr,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // PUT /api/my-store/orders/{id}/confirm: Xác nhận đơn
  Future<Order> confirmOrder(int orderId) async {
    final res = await _dio.put('/api/my-store/orders/$orderId/confirm');
    return Order.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/my-store/orders/{id}/complete: Hoàn thành đơn
  Future<Order> completeOrder(int orderId) async {
    final res = await _dio.put('/api/my-store/orders/$orderId/complete');
    return Order.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/my-store/orders/{id}/cancel: Hủy đơn
  Future<Order> cancelOrder(int orderId) async {
    final res = await _dio.put('/api/my-store/orders/$orderId/cancel');
    return Order.fromJson(Map<String, dynamic>.from(res.data));
  }

  // === ĐÁNH GIÁ & THỐNG KÊ ===

  // GET /api/my-store/reviews
  Future<List<StoreReview>> getReviews() async {
    final res = await _dio.get('/api/my-store/reviews');
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => StoreReview.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/my-store/statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final res = await _dio.get('/api/my-store/statistics');
    return Map<String, dynamic>.from(res.data);
  }
}

