import 'package:dio/dio.dart';
import 'package:icitizen_app/core/api_client.dart';

import 'chat_models.dart';

class SupportService {
  final Dio _dio = api.dio;

  Future<List<SupportTicket>> listTickets({
    SupportTicketStatus? status,
    String? search,
    String? apartmentCode,
    String? assignedToId,
  }) async {
    final qp = <String, dynamic>{
      if (status != null) 'status': _statusToApi(status),
      if (search != null && search.isNotEmpty) 'search': search,
      if (apartmentCode != null && apartmentCode.isNotEmpty) 'apartmentCode': apartmentCode,
      if (assignedToId != null && assignedToId.isNotEmpty) 'assignedToId': assignedToId,
    };

    final r = await _dio.get('/api/support/tickets', queryParameters: qp);
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(SupportTicket.fromJson).toList();
  }

  Future<SupportTicketDetail> getTicketDetail(String ticketId) async {
    final r = await _dio.get('/api/support/tickets/$ticketId');
    return SupportTicketDetail.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<SupportTicketDetail> createTicket({
    required String title,
    required String content,
    String? category,
    String? attachmentUrl,
  }) async {
    final r = await _dio.post('/api/support/tickets', data: {
      'title': title,
      'content': content,
      if (category != null && category.isNotEmpty) 'category': category,
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
    });
    return SupportTicketDetail.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final r = await _dio.get('/api/support/tickets/$ticketId/messages');
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(SupportMessage.fromJson).toList();
  }

  Future<SupportMessage> sendMessage(
    String ticketId,
    String content, {
    String? attachmentUrl,
  }) async {
    final r = await _dio.post('/api/support/tickets/$ticketId/messages', data: {
      'content': content,
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
    });
    return SupportMessage.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> updateStatus(String ticketId, SupportTicketStatus status) async {
    await _dio.put('/api/support/tickets/$ticketId/status', data: {
      'status': _statusToApi(status),
    });
  }

  Future<void> assignTo(String ticketId, String? userId) async {
    await _dio.put('/api/support/tickets/$ticketId/assign', data: {
      'assignedToId': userId,
    });
  }

  String _statusToApi(SupportTicketStatus status) {
    switch (status) {
      case SupportTicketStatus.newTicket:
        return 'New';
      case SupportTicketStatus.inProgress:
        return 'InProgress';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
    }
  }
}

class CommunityChatService {
  final Dio _dio = api.dio;

  Future<List<CommunityMessageModel>> fetchMessages({
    String room = 'general',
    int limit = 50,
    DateTime? before,
    DateTime? after,
  }) async {
    final qp = <String, dynamic>{
      'room': room,
      'limit': limit,
      if (before != null) 'before': before.toUtc().toIso8601String(),
      if (after != null) 'after': after.toUtc().toIso8601String(),
    };
    final r = await _dio.get('/api/community/messages', queryParameters: qp);
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(CommunityMessageModel.fromJson).toList();
  }

  Future<CommunityMessageModel> sendMessage({
    String room = 'general',
    String? content,
    String? attachmentType,
    String? fileBase64,
    String? fileName,
    double? durationSeconds,
  }) async {
    final body = <String, dynamic>{
      'room': room,
      if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
      if (attachmentType != null) 'attachmentType': attachmentType,
      if (fileBase64 != null) 'fileBase64': fileBase64,
      if (fileName != null) 'fileName': fileName,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };

    final r = await _dio.post('/api/community/messages', data: body);
    return CommunityMessageModel.fromJson(Map<String, dynamic>.from(r.data));
  }
}

// Service cho Community Posts (Bảng tin)
class CommunityPostService {
  final Dio _dio = api.dio;

  // Lấy danh sách bài đăng với phân trang
  Future<List<CommunityPost>> fetchPosts({
    required PostType type,
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final qp = <String, dynamic>{
      'type': postTypeToString(type),
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    try {
      final r = await _dio.get('/api/community/posts', queryParameters: qp);
      final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      return data.map((json) {
        try {
          return CommunityPost.fromJson(json);
        } catch (e) {
          print('Lỗi parse CommunityPost: $e\nJSON: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      print('Lỗi fetchPosts: $e\nQuery params: $qp');
      rethrow;
    }
  }

  // Lấy chi tiết một bài đăng
  Future<CommunityPost> getPost(String postId) async {
    final r = await _dio.get('/api/community/posts/$postId');
    return CommunityPost.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Tạo bài đăng mới
  Future<CommunityPost> createPost({
    required PostType type,
    required String title,
    required String content,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{
      'type': postTypeToString(type),
      'title': title.trim(),
      'content': content.trim(),
      if (imageUrls != null && imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    };
    final r = await _dio.post('/api/community/posts', data: body);
    return CommunityPost.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Cập nhật bài đăng
  Future<CommunityPost> updatePost({
    required String postId,
    String? title,
    String? content,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (content != null) 'content': content.trim(),
      if (imageUrls != null) 'imageUrls': imageUrls,
    };
    final r = await _dio.put('/api/community/posts/$postId', data: body);
    return CommunityPost.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Xóa bài đăng
  Future<void> deletePost(String postId) async {
    await _dio.delete('/api/community/posts/$postId');
  }

  // Thích/Bỏ thích bài đăng
  Future<CommunityPost> toggleLike(String postId) async {
    final r = await _dio.post('/api/community/posts/$postId/like');
    return CommunityPost.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Lấy danh sách bình luận
  Future<List<PostComment>> fetchComments({
    required String postId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    final r = await _dio.get('/api/community/posts/$postId/comments', queryParameters: qp);
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(PostComment.fromJson).toList();
  }

  // Tạo bình luận hoặc reply
  Future<PostComment> createComment({
    required String postId,
    required String content,
    String? parentCommentId, // ID của comment cha nếu là reply
  }) async {
    final r = await _dio.post('/api/community/posts/$postId/comments', data: {
      'content': content.trim(),
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    });
    return PostComment.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Cập nhật bình luận
  Future<PostComment> updateComment({
    required String postId,
    required String commentId,
    required String content,
  }) async {
    final r = await _dio.put('/api/community/posts/$postId/comments/$commentId', data: {
      'content': content.trim(),
    });
    return PostComment.fromJson(Map<String, dynamic>.from(r.data));
  }

  // Xóa bình luận
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _dio.delete('/api/community/posts/$postId/comments/$commentId');
  }

  // Lấy danh sách người đã like
  Future<List<PostLikeUser>> getLikes({
    required String postId,
  }) async {
    final r = await _dio.get('/api/community/posts/$postId/likes');
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(PostLikeUser.fromJson).toList();
  }

  // Like/Unlike bình luận
  Future<Map<String, dynamic>> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    final r = await _dio.post('/api/community/posts/$postId/comments/$commentId/like');
    return Map<String, dynamic>.from(r.data);
  }

  // Ẩn bình luận (chỉ admin)
  Future<void> hideComment({
    required String postId,
    required String commentId,
  }) async {
    await _dio.put('/api/community/posts/$postId/comments/$commentId/hide');
  }

  // Lấy danh sách reply của một comment
  Future<List<PostComment>> getReplies({
    required String postId,
    required String commentId,
  }) async {
    final r = await _dio.get('/api/community/posts/$postId/comments/$commentId/replies');
    final data = (r.data as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(PostComment.fromJson).toList();
  }

  // Cập nhật trạng thái kiến nghị (chỉ admin)
  Future<CommunityPost> updateSuggestionStatus({
    required String postId,
    required SuggestionStatus status,
  }) async {
    final r = await _dio.put('/api/community/posts/$postId/status', data: {
      'status': _statusToApi(status),
    });
    return CommunityPost.fromJson(Map<String, dynamic>.from(r.data));
  }

  String _statusToApi(SuggestionStatus status) {
    switch (status) {
      case SuggestionStatus.newSuggestion:
        return 'New';
      case SuggestionStatus.inProgress:
        return 'InProgress';
      case SuggestionStatus.completed:
        return 'Completed';
      case SuggestionStatus.rejected:
        return 'Rejected';
    }
  }
}
