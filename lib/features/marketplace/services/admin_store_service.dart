// Service cho Admin quản lý cửa hàng
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../models/store_model.dart';

class AdminStoreService {
  final Dio _dio = api.dio;

  // GET /api/admin/stores/pending: Lấy danh sách các Store chờ duyệt
  Future<List<Store>> getPendingStores() async {
    final res = await _dio.get('/api/admin/stores/pending');
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/admin/stores: Lấy danh sách tất cả cửa hàng
  Future<List<Store>> getAllStores({String? search, bool? isActive}) async {
    final res = await _dio.get('/api/admin/stores', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (isActive != null) 'isActive': isActive,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data['data'] as List? ?? [])
        : res.data as List;
    return data.map((e) => Store.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // PUT /api/admin/stores/{id}/approve: Duyệt Cửa hàng
  Future<Store> approveStore(int storeId) async {
    final res = await _dio.put('/api/admin/stores/$storeId/approve');
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/admin/stores/{id}/toggle-active: Tạm khóa/Mở khóa cửa hàng
  Future<Store> toggleStoreActive(int storeId) async {
    final res = await _dio.put('/api/admin/stores/$storeId/toggle-active');
    return Store.fromJson(Map<String, dynamic>.from(res.data));
  }

  // GET /api/admin/marketplace/statistics: Lấy thống kê marketplace
  Future<Map<String, dynamic>> getStatistics() async {
    final res = await _dio.get('/api/admin/marketplace/statistics');
    return Map<String, dynamic>.from(res.data);
  }
}

