// Service cho Marketplace (người mua)
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/store_review_model.dart';

class MarketplaceService {
  final Dio _dio = api.dio;

  // GET /api/marketplace/stores: Lấy danh sách tất cả Store đã được duyệt
  Future<List<Store>> getStores({String? search}) async {
    final res = await _dio.get('/api/marketplace/stores', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/marketplace/stores/{id}: Lấy "Trang Cửa hàng" công khai
  Future<Store> getStore(int storeId) async {
    final res = await _dio.get('/api/marketplace/stores/$storeId');
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // GET /api/marketplace/stores/{id}/products: Lấy danh sách sản phẩm của cửa hàng
  Future<List<Product>> getStoreProducts(int storeId, {int? categoryId}) async {
    final res = await _dio.get('/api/marketplace/stores/$storeId/products', queryParameters: {
      if (categoryId != null) 'categoryId': categoryId,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/marketplace/products/{id}: Xem chi tiết 1 sản phẩm
  Future<Product> getProduct(int productId) async {
    final res = await _dio.get('/api/marketplace/products/$productId');
    return Product.fromJson(Map<String, dynamic>.from(res.data));
  }

  // GET /api/marketplace/products: Tìm kiếm sản phẩm
  Future<List<Product>> searchProducts({String? search, int? storeId}) async {
    final res = await _dio.get('/api/marketplace/products', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (storeId != null) 'storeId': storeId,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Product.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/marketplace/my-orders: Xem lịch sử đơn hàng mình đã mua
  Future<List<Order>> getMyOrders() async {
    final res = await _dio.get('/api/marketplace/my-orders');
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/marketplace/orders/{id}: Xem chi tiết đơn hàng
  Future<Order> getOrder(int orderId) async {
    final res = await _dio.get('/api/marketplace/orders/$orderId');
    return Order.fromJson(Map<String, dynamic>.from(res.data));
  }

  // POST /api/marketplace/orders: Tạo đơn hàng mới
  Future<Order> createOrder({
    required int storeId,
    required List<Map<String, dynamic>> items, // [{productId, quantity}]
    String? notes,
  }) async {
    final res = await _dio.post(
      '/api/marketplace/orders',
      data: {
        'storeId': storeId,
        'items': items,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return Order.fromJson(Map<String, dynamic>.from(res.data));
  }

  // GET /api/marketplace/stores/{id}/reviews: Lấy đánh giá của cửa hàng
  Future<List<StoreReview>> getStoreReviews(int storeId) async {
    final res = await _dio.get('/api/marketplace/stores/$storeId/reviews');
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => StoreReview.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // POST /api/marketplace/reviews: Gửi đánh giá cho Store
  Future<StoreReview> createReview({
    required int storeId,
    required int rating,
    String? comment,
    int? orderId,
  }) async {
    final res = await _dio.post(
      '/api/marketplace/reviews',
      data: {
        'storeId': storeId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (orderId != null) 'orderId': orderId,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return StoreReview.fromJson(Map<String, dynamic>.from(res.data));
  }
}

