import 'package:dio/dio.dart';
import '../../core/api_client.dart';

class _Endpoints {
  static const listMyTasks = '/api/Complaints'; // GET ?assignedToMe=true&status=InProgress (hoặc New)
  static String setStatus(String id) => '/api/Complaints/$id/status'; // POST {status:"..."}
  static String comments(String id) => '/api/Complaints/$id/comments';
}

class TaskStatus {
  static const new_ = 'New';
  static const inProgress = 'InProgress';
  static const resolved = 'Resolved';
  static const rejected = 'Rejected';
}

class VendorTask {
  final String id, title, content, category, status;
  VendorTask({required this.id, required this.title, required this.content, required this.category, required this.status});
  factory VendorTask.fromJson(Map<String, dynamic> j) => VendorTask(
    id: j['id'].toString(),
    title: j['title'] ?? '',
    content: j['content'] ?? '',
    category: j['category']?.toString() ?? '',
    status: j['status']?.toString() ?? '',
  );
}

class VendorService {
  final Dio _dio = api.dio;

  Future<List<VendorTask>> listMyTasks({String? status, String? category, int page=1, int pageSize=30}) async {
    final res = await _dio.get(_Endpoints.listMyTasks, queryParameters: {
      'assignedToMe': true,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      'page': page, 'pageSize': pageSize,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data as List)
        : res.data as List;
    return data.map((e) => VendorTask.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> setStatus(String id, String status) async {
    await _dio.post(_Endpoints.setStatus(id),
        data: {'status': status},
        options: Options(headers: {'Content-Type': 'application/json'}));
  }

  Future<void> addComment(String id, String message) async {
    await _dio.post(_Endpoints.comments(id),
        data: message,
        options: Options(headers: {'Content-Type': 'text/plain'}));
  }
}
