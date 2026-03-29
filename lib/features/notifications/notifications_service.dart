import '../../core/api_client.dart';
import 'notification_model.dart';

class NotificationsService {
  Future<List<NotificationModel>> list({int page=1, int pageSize=20, bool onlyActive=true, String? search}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize, 'onlyActive': onlyActive};
    if (search != null) queryParams['search'] = search;
    final res = await api.dio.get('/api/Notifications', queryParameters: queryParams);
    final items = (res.data['items'] as List).map((e)=> NotificationModel.fromJson(Map<String,dynamic>.from(e))).toList();
    return items;
  }

  Future<int> countActive({bool onlyActive = true}) async {
    final queryParams = <String, dynamic>{
      'page': 1,
      'pageSize': 1,
      'onlyActive': onlyActive,
    };
    final res = await api.dio.get('/api/Notifications', queryParameters: queryParams);
    final total = res.data['total'];
    if (total is int) return total;
    final items = res.data['items'] as List?;
    return items?.length ?? 0;
  }

  Future<NotificationModel> getById(String id) async {
    final res = await api.dio.get('/api/Notifications/$id');
    return NotificationModel.fromJson(Map<String,dynamic>.from(res.data));
  }

  // ========== ADMIN ==========
  Future<NotificationModel> create(NotificationModel m) async {
    final res = await api.dio.post('/api/Notifications', data: m.toJson());
    return NotificationModel.fromJson(Map<String,dynamic>.from(res.data));
  }

  Future<void> update(String id, NotificationModel m) async {
    await api.dio.put('/api/Notifications/$id', data: m.toJson());
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/api/Notifications/$id');
  }
}
