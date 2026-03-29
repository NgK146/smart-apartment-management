import '../../core/api_client.dart';

class AccessControlService {
  /// Mở cửa thông minh và nhận blockchain proof
  Future<Map<String, dynamic>> openDoor({
    required String roomNumber,
    required String username,
  }) async {
    final res = await api.dio.post(
      '/api/Access/open-door',
      data: {
        'roomNumber': roomNumber,
        'username': username,
      },
    );
    return {
      'status': res.data['status']?.toString() ?? '',
      'timestamp': res.data['timestamp']?.toString() ?? '',
      'security_proof': res.data['security_proof']?.toString() ?? '',
    };
  }

  /// Lấy lịch sử truy cập cửa
  Future<Map<String, dynamic>> getAccessHistory(String roomNumber) async {
    final res = await api.dio.get(
      '/api/Access/history',
      queryParameters: {'roomNumber': roomNumber},
    );
    return res.data as Map<String, dynamic>;
  }
}

final accessControlService = AccessControlService();

