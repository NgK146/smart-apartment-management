import 'package:dio/dio.dart';
import '../../features/visitor/models/visitor_access.dart';

class VisitorService {
  final Dio _dio;

  VisitorService(this._dio);

  /// Tạo visitor access và QR code
  Future<VisitorAccess> createVisitorAccess({
    required String visitorName,
    String? visitorPhone,
    String? visitorEmail,
    required DateTime visitDate,
    String? visitTime,
    String? purpose,
  }) async {
    final response = await _dio.post(
      '/api/Visitor/create',
      data: {
        'visitorName': visitorName,
        'visitorPhone': visitorPhone,
        'visitorEmail': visitorEmail,
        'visitDate': visitDate.toIso8601String(),
        'visitTime': visitTime,
        'purpose': purpose,
      },
    );
    return VisitorAccess.fromJson(response.data);
  }

  /// Lấy danh sách visitor access của cư dân
  Future<List<VisitorAccess>> getMyVisitors({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/api/Visitor/my-visitors',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (response.data['items'] as List)
        .map((json) => VisitorAccess.fromJson(json))
        .toList();
  }

  /// Lấy chi tiết visitor access theo ID
  Future<VisitorAccess> getVisitorById(String id) async {
    final response = await _dio.get('/api/Visitor/$id');
    return VisitorAccess.fromJson(response.data);
  }

  /// Check-in visitor bằng QR code
  Future<VisitorAccess> checkInVisitor(String qrCode) async {
    final response = await _dio.post(
      '/api/Visitor/check-in',
      data: {'qrCode': qrCode},
    );
    return VisitorAccess.fromJson(response.data);
  }

  /// Check-out visitor
  Future<VisitorAccess> checkOutVisitor(String id) async {
    final response = await _dio.post('/api/Visitor/$id/check-out');
    return VisitorAccess.fromJson(response.data);
  }

  /// Hủy visitor access
  Future<void> cancelVisitor(String id) async {
    await _dio.delete('/api/Visitor/$id');
  }

  /// Validate QR code (dùng khi scan QR)
  Future<VisitorAccess?> validateQRCode(String qrCode) async {
    try {
      final response = await _dio.post(
        '/api/Visitor/validate-qr',
        data: {'qrCode': qrCode},
      );
      return VisitorAccess.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // QR code không hợp lệ
      }
      rethrow;
    }
  }

  // ========== ADMIN METHODS ==========

  /// Lấy tất cả visitor access (Admin only)
  Future<List<VisitorAccess>> getAllVisitors({
    int page = 1,
    int pageSize = 100,
    String? search,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _dio.get(
      '/api/Visitor/admin/all',
      queryParameters: queryParams,
    );
    return (response.data['items'] as List? ?? response.data as List)
        .map((json) => VisitorAccess.fromJson(json))
        .toList();
  }

  /// Tạo visitor access cho cư dân cụ thể (Admin only)
  Future<VisitorAccess> createVisitorForResident({
    required String residentId,
    required String apartmentCode,
    required String visitorName,
    String? visitorPhone,
    String? visitorEmail,
    required DateTime visitDate,
    String? visitTime,
    String? purpose,
  }) async {
    final response = await _dio.post(
      '/api/Visitor/admin/create',
      data: {
        'residentId': residentId,
        'apartmentCode': apartmentCode,
        'visitorName': visitorName,
        'visitorPhone': visitorPhone,
        'visitorEmail': visitorEmail,
        'visitDate': visitDate.toIso8601String(),
        'visitTime': visitTime,
        'purpose': purpose,
      },
    );
    return VisitorAccess.fromJson(response.data);
  }
}

