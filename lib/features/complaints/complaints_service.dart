import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import 'complaint_model.dart';

class ComplaintsService {
  Future<List<ComplaintModel>> list({int page=1, int pageSize=20, String? status, String? category, bool? assignedToMe}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;
    if (assignedToMe == true) queryParams['assignedToMe'] = true;
    
    final res = await api.dio.get('/api/Complaints', queryParameters: queryParams);
    final items = (res.data['items'] as List).map((e)=> ComplaintModel.fromJson(Map<String,dynamic>.from(e))).toList();
    return items;
  }

  // Gửi phản ánh
  Future<ComplaintModel> create({
    required String title, 
    required String content, 
    String? category,
    String? emailNguoiGui,
    String? tenNguoiGui,
    String? mediaUrls,
  }) async {
    try {
      final res = await api.dio.post('/api/Complaints', data: {
        'title': title, 
        'content': content, 
        if (category != null) 'category': category,
        if (emailNguoiGui != null && emailNguoiGui.isNotEmpty) 'emailNguoiGui': emailNguoiGui,
        if (tenNguoiGui != null && tenNguoiGui.isNotEmpty) 'tenNguoiGui': tenNguoiGui,
        if (mediaUrls != null) 'mediaUrls': mediaUrls
      });
      if (res.data == null) {
        throw Exception('Không có dữ liệu phản hồi');
      }
      return ComplaintModel.fromJson(Map<String,dynamic>.from(res.data));
    } catch (e) {
      print('Error creating complaint: $e');
      rethrow;
    }
  }

  // Lấy danh sách phản ánh của user hiện tại
  Future<(List<ComplaintModel> items, int total)> getMyComplaints({int page = 1, int pageSize = 20}) async {
    try {
      final res = await api.dio.get('/api/Complaints/me', queryParameters: {'page': page, 'pageSize': pageSize});
      if (res.data == null || res.data['items'] == null) {
        return (<ComplaintModel>[], 0);
      }
      final itemsList = res.data['items'] as List? ?? [];
      final items = itemsList.map((e) {
        try {
          return ComplaintModel.fromJson(Map<String, dynamic>.from(e));
        } catch (e) {
          // Log error but continue
          print('Error parsing complaint: $e');
          return null;
        }
      }).whereType<ComplaintModel>().toList();
      final total = res.data['total'] as int? ?? items.length;
      return (items, total);
    } catch (e) {
      print('Error loading complaints: $e');
      rethrow;
    }
  }

  Future<int> countMyComplaints({String? status}) async {
    final queryParams = <String, dynamic>{'page': 1, 'pageSize': 1};
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/Complaints', queryParameters: queryParams);
    final total = res.data['total'];
    if (total is int) return total;
    final items = res.data['items'] as List?;
    return items?.length ?? 0;
  }

  // Xem chi tiết phản ánh
  Future<ComplaintModel> getDetails(String id) async {
    try {
      final res = await api.dio.get('/api/Complaints/$id');
      if (res.data == null) {
        throw Exception('Không có dữ liệu');
      }
      return ComplaintModel.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      print('Error loading complaint details: $e');
      rethrow;
    }
  }

  // Upload ảnh
  Future<String> uploadImage(XFile imageFile) async {
    try {
      final file = File(imageFile.path);
      final fileName = imageFile.name;
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final res = await api.dio.post(
        '/api/Complaints/upload-image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (res.data == null || res.data['url'] == null) {
        // Nếu API không trả về URL, thử dùng base64
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Image';
      }

      return res.data['url'].toString();
    } catch (e) {
      print('Error uploading image: $e');
      // Fallback: trả về base64 nếu upload thất bại
      try {
        final file = File(imageFile.path);
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Image';
      } catch (e2) {
        throw Exception('Không thể upload ảnh: $e');
      }
    }
  }

  // Gửi comment (User và Admin)
  Future<CommentModel> addComment(String complaintId, String message) async {
    try {
      final res = await api.dio.post(
        '/api/Complaints/$complaintId/comments', 
        data: {'message': message},
      );
      if (res.data == null) {
        throw Exception('Không có dữ liệu phản hồi');
      }
      return CommentModel.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }
}