import '../../core/api_client.dart';
import 'models/concierge_service.dart';

class AdminConciergeService {
  /// Lấy danh sách yêu cầu concierge (admin)
  Future<(List<ConciergeRequest>, int)> list({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final res =
        await api.dio.get('/api/admin/Concierge/requests', queryParameters: query);
    final items = (res.data['items'] as List)
        .map((e) => ConciergeRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = res.data['total'] as int? ?? items.length;
    return (items, total);
  }

  /// Cập nhật trạng thái yêu cầu
  Future<void> updateStatus(String id, String status) async {
    await api.dio.put(
      '/api/admin/Concierge/requests/$id/status',
      data: {'status': status},
    );
  }
}


