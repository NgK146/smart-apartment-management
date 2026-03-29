import 'package:dio/dio.dart';
import '../../features/concierge/models/concierge_service.dart';

class ConciergeApiService {
  final Dio _dio;

  ConciergeApiService(this._dio);

  /// Lấy danh sách dịch vụ concierge
  Future<List<ConciergeService>> getServices() async {
    final response = await _dio.get('/api/Concierge/services');
    return (response.data as List)
        .map((json) => ConciergeService.fromJson(json))
        .toList();
  }

  /// Tạo yêu cầu dịch vụ
  Future<ConciergeRequest> createRequest({
    required String serviceId,
    String? serviceName,
    DateTime? scheduledFor,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/api/Concierge/requests',
      data: {
        'serviceId': serviceId,
        'serviceName': serviceName,
        'scheduledFor': scheduledFor?.toIso8601String(),
        'notes': notes,
      },
    );
    return ConciergeRequest.fromJson(response.data);
  }

  /// Lấy danh sách yêu cầu của cư dân
  Future<List<ConciergeRequest>> getMyRequests({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/api/Concierge/my-requests',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (response.data['items'] as List)
        .map((json) => ConciergeRequest.fromJson(json))
        .toList();
  }

  /// Hủy yêu cầu
  Future<void> cancelRequest(String requestId) async {
    await _dio.delete('/api/Concierge/requests/$requestId');
  }
}

