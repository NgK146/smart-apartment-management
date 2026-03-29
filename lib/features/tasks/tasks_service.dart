import '../../core/api_client.dart';
import 'task_model.dart';

class TasksService {
  Future<List<InternalTaskModel>> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? type,
    bool? assignedToMe,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (status != null) queryParams['status'] = status;
    if (type != null) queryParams['type'] = type;
    if (assignedToMe == true) queryParams['assignedToMe'] = true;
    if (search != null) queryParams['search'] = search;
    final res = await api.dio.get('/api/InternalTasks', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => InternalTaskModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<InternalTaskModel> get(String id) async {
    final res = await api.dio.get('/api/InternalTasks/$id');
    return InternalTaskModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> complete(String id) async {
    await api.dio.put('/api/InternalTasks/$id/complete');
  }
}

























