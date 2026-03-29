import 'package:dio/dio.dart';
import '../../features/events/models/community_event.dart';

class EventsService {
  final Dio _dio;

  EventsService(this._dio);

  /// Lấy danh sách sự kiện
  Future<List<CommunityEvent>> getEvents({
    EventCategory? category,
    EventStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/api/Events',
        queryParameters: {
          if (category != null) 'category': category.toString().split('.').last,
          if (status != null) 'status': status.toString().split('.').last,
          'page': page,
          'pageSize': pageSize,
        },
      );
      return (response.data['items'] as List)
          .map((json) => CommunityEvent.fromJson(json))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Endpoint chưa có, trả về danh sách rỗng
        return [];
      }
      rethrow;
    }
  }

  /// Đăng ký tham gia sự kiện
  Future<EventRegistration> registerEvent(String eventId) async {
    final response = await _dio.post(
      '/api/Events/$eventId/register',
    );
    return EventRegistration.fromJson(response.data);
  }

  /// Hủy đăng ký
  Future<void> cancelRegistration(String eventId) async {
    await _dio.delete('/api/Events/$eventId/register');
  }

  /// Lấy danh sách sự kiện đã đăng ký
  Future<List<EventRegistration>> getMyRegistrations() async {
    try {
      final response = await _dio.get('/api/Events/my-registrations');
      return (response.data as List)
          .map((json) => EventRegistration.fromJson(json))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Endpoint chưa có, trả về danh sách rỗng
        return [];
      }
      rethrow;
    }
  }

  /// Check-in sự kiện bằng QR code
  Future<EventRegistration> checkInEvent(String qrCode) async {
    final response = await _dio.post(
      '/api/Events/check-in',
      data: {'qrCode': qrCode},
    );
    return EventRegistration.fromJson(response.data);
  }

  /// Validate QR code cho check-in
  Future<EventRegistration?> validateCheckInQR(String qrCode) async {
    try {
      final response = await _dio.post(
        '/api/Events/validate-check-in-qr',
        data: {'qrCode': qrCode},
      );
      return EventRegistration.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

