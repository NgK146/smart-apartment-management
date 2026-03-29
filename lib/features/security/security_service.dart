import 'package:dio/dio.dart';
import '../../core/api_client.dart';

/// Định nghĩa endpoint – SỬA TẠI ĐÂY nếu backend khác path
class _Endpoints {
  static const listComplaints = '/api/Complaints'; // GET ?status=New&category=Security&assignedToMe=true
  static String assignToMe(String id) => '/api/Complaints/$id/assign-to-me'; // POST
  static String setStatus(String id) => '/api/Complaints/$id/status';       // POST {status:"InProgress"}
  static String comments(String id) => '/api/Complaints/$id/comments';      // POST body: string (text/plain)
  static const createComplaint = '/api/Complaints';                         // POST để ghi nhận "sự cố"
}

/// Các trạng thái hỗ trợ
class ComplaintStatus {
  static const new_ = 'New';
  static const inProgress = 'InProgress';
  static const resolved = 'Resolved';
  static const rejected = 'Rejected';
}

class ComplaintItem {
  final String id, title, content, category, status;
  final String? createdBy;
  final DateTime? createdAt;
  ComplaintItem({
    required this.id, required this.title, required this.content,
    required this.category, required this.status, this.createdBy, this.createdAt,
  });
  factory ComplaintItem.fromJson(Map<String, dynamic> j) => ComplaintItem(
    id: j['id'].toString(),
    title: j['title'] ?? '',
    content: j['content'] ?? '',
    category: j['category']?.toString() ?? '',
    status: j['status']?.toString() ?? '',
    createdBy: j['createdBy']?.toString(),
    createdAt: j['createdAtUtc'] != null ? DateTime.tryParse(j['createdAtUtc']) : null,
  );
}

class SecurityService {
  final Dio _dio = api.dio;

  Future<List<ComplaintItem>> listComplaints({
    String? status, bool? assignedToMe, String? category, int page = 1, int pageSize = 30,
  }) async {
    final res = await _dio.get(_Endpoints.listComplaints, queryParameters: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (assignedToMe != null) 'assignedToMe': assignedToMe,
      'page': page, 'pageSize': pageSize,
    });
    final data = res.data is Map<String, dynamic>
        ? (res.data['items'] as List? ?? res.data as List)
        : res.data as List;
    return data.map((e) => ComplaintItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> assignToMe(String complaintId) async {
    await _dio.post(_Endpoints.assignToMe(complaintId));
  }

  Future<void> setStatus(String complaintId, String status) async {
    await _dio.post(_Endpoints.setStatus(complaintId),
        data: {'status': status},
        options: Options(headers: {'Content-Type': 'application/json'}));
  }

  Future<void> addComment(String complaintId, String message) async {
    await _dio.post(_Endpoints.comments(complaintId),
        data: message,
        options: Options(headers: {'Content-Type': 'text/plain'}));
  }

  /// Ghi nhận một "Sự cố an ninh" (tận dụng Complaints với category = Security)
  Future<ComplaintItem> createIncident({required String title, required String content}) async {
    final res = await _dio.post(_Endpoints.createComplaint,
        data: {'title': title, 'content': content, 'category': 'Security'},
        options: Options(headers: {'Content-Type': 'application/json'}));
    return ComplaintItem.fromJson(Map<String, dynamic>.from(res.data));
  }
}
