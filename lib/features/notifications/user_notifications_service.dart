import '../../core/api_client.dart';
import 'user_notification_model.dart';

class UserNotificationsService {
  Future<({List<UserNotificationModel> items, int unreadCount})> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final res = await api.dio.get('/api/UserNotifications', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      'unreadOnly': unreadOnly,
    });
    final items = (res.data['items'] as List)
        .map((e) => UserNotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final unreadCount = res.data['unreadCount'] is int ? res.data['unreadCount'] as int : 0;
    return (items: items, unreadCount: unreadCount);
  }

  Future<void> markRead(String id) async {
    await api.dio.patch('/api/UserNotifications/$id/read');
  }

  Future<void> markAllRead() async {
    await api.dio.patch('/api/UserNotifications/read-all');
  }
}

final userNotificationsService = UserNotificationsService();


