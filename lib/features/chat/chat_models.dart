// 所有注释保持中文，符合项目要求

enum SupportTicketStatus { newTicket, inProgress, resolved, closed }

SupportTicketStatus supportTicketStatusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'inprogress':
    case 'in_progress':
      return SupportTicketStatus.inProgress;
    case 'resolved':
      return SupportTicketStatus.resolved;
    case 'closed':
      return SupportTicketStatus.closed;
    default:
      return SupportTicketStatus.newTicket;
  }
}

String supportTicketStatusToDisplay(SupportTicketStatus status) {
  switch (status) {
    case SupportTicketStatus.newTicket:
      return 'Mới';
    case SupportTicketStatus.inProgress:
      return 'Đang xử lý';
    case SupportTicketStatus.resolved:
      return 'Đã xử lý';
    case SupportTicketStatus.closed:
      return 'Đã đóng';
  }
}

class SupportTicket {
  final String id;
  final String title;
  final String createdById;
  final String createdByName;
  final String? apartmentCode;
  final SupportTicketStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final String? assignedToId;
  final String? assignedToName;

  SupportTicket({
    required this.id,
    required this.title,
    required this.createdById,
    required this.createdByName,
    required this.apartmentCode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.assignedToId,
    required this.assignedToName,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: (j['ticketId'] ?? j['id']).toString(),
        title: (j['title'] ?? '') as String,
        createdById: (j['createdById'] ?? '') as String,
        createdByName: (j['createdByName'] ?? '') as String,
        apartmentCode: j['apartmentCode'] as String?,
        status: supportTicketStatusFromString(j['status']?.toString()),
        createdAt: DateTime.parse(j['createdAtUtc'] as String),
        updatedAt: j['updatedAtUtc'] == null
            ? null
            : DateTime.tryParse(j['updatedAtUtc'] as String),
        lastMessagePreview: j['lastMessagePreview'] as String?,
        lastMessageAt: j['lastMessageAtUtc'] == null
            ? null
            : DateTime.tryParse(j['lastMessageAtUtc'] as String),
        assignedToId: j['assignedToId'] as String?,
        assignedToName: j['assignedToName'] as String?,
      );
}

class SupportTicketDetail extends SupportTicket {
  final String? category;
  final List<SupportMessage> messages;

  SupportTicketDetail({
    required super.id,
    required super.title,
    required super.createdById,
    required super.createdByName,
    required super.apartmentCode,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required super.lastMessagePreview,
    required super.lastMessageAt,
    required super.assignedToId,
    required super.assignedToName,
    required this.category,
    required this.messages,
  });

  factory SupportTicketDetail.fromJson(Map<String, dynamic> j) => SupportTicketDetail(
        id: (j['ticketId'] ?? j['id']).toString(),
        title: (j['title'] ?? '') as String,
        createdById: (j['createdById'] ?? '') as String,
        createdByName: (j['createdByName'] ?? '') as String,
        apartmentCode: j['apartmentCode'] as String?,
        status: supportTicketStatusFromString(j['status']?.toString()),
        createdAt: DateTime.parse(j['createdAtUtc'] as String),
        updatedAt: j['updatedAtUtc'] == null
            ? null
            : DateTime.tryParse(j['updatedAtUtc'] as String),
        lastMessagePreview: j['lastMessagePreview'] as String?,
        lastMessageAt: j['lastMessageAtUtc'] == null
            ? null
            : DateTime.tryParse(j['lastMessageAtUtc'] as String),
        assignedToId: j['assignedToId'] as String?,
        assignedToName: j['assignedToName'] as String?,
        category: j['category'] as String?,
        messages: (j['messages'] as List<dynamic>? ?? const [])
            .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String content;
  final String? attachmentUrl;
  final DateTime createdAt;
  final bool isFromStaff;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.attachmentUrl,
    required this.createdAt,
    required this.isFromStaff,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: (j['id'] ?? '').toString(),
        ticketId: (j['ticketId'] ?? '').toString(),
        senderId: (j['senderId'] ?? '').toString(),
        senderName: (j['senderName'] ?? '') as String,
        content: (j['content'] ?? '') as String,
        attachmentUrl: j['attachmentUrl'] as String?,
        createdAt: DateTime.parse(j['createdAtUtc'] as String),
        isFromStaff: j['isFromStaff'] as bool? ?? false,
      );
}

class CommunityMessageModel {
  final String id;
  final String room;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final String? attachmentType;
  final String? attachmentUrl;
  final double? attachmentDurationSeconds;

  CommunityMessageModel({
    required this.id,
    required this.room,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.attachmentType,
    this.attachmentUrl,
    this.attachmentDurationSeconds,
  });

  factory CommunityMessageModel.fromJson(Map<String, dynamic> j) => CommunityMessageModel(
        id: (j['id'] ?? '').toString(),
        room: (j['room'] ?? 'general').toString(),
        senderId: (j['senderId'] ?? '').toString(),
        senderName: (j['senderName'] ?? 'Ẩn danh') as String,
        content: (j['content'] ?? '') as String,
        attachmentType: j['attachmentType'] as String?,
        attachmentUrl: j['attachmentUrl'] as String?,
        attachmentDurationSeconds: (j['attachmentDurationSeconds'] as num?)?.toDouble(),
        createdAt: DateTime.parse((j['createdAtUtc'] ?? j['createdAt']).toString()),
      );
}

// Enum cho loại bài đăng
enum PostType { news, discussion, suggestion }

PostType postTypeFromString(String? value) {
  if (value == null) return PostType.discussion;
  final lower = value.toLowerCase();
  switch (lower) {
    case 'news':
    case 'tintuc':
    case '0': // Enum value 0 = News
      return PostType.news;
    case 'suggestion':
    case 'kiennghi':
    case '2': // Enum value 2 = Suggestion
      return PostType.suggestion;
    case 'discussion':
    case 'thaoluan':
    case '1': // Enum value 1 = Discussion
    default:
      return PostType.discussion;
  }
}

String postTypeToString(PostType type) {
  switch (type) {
    case PostType.news:
      return 'news';
    case PostType.discussion:
      return 'discussion';
    case PostType.suggestion:
      return 'suggestion';
  }
}

// Enum cho trạng thái kiến nghị
enum SuggestionStatus { newSuggestion, inProgress, completed, rejected }

SuggestionStatus suggestionStatusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'inprogress':
    case 'in_progress':
    case 'dangxuly':
      return SuggestionStatus.inProgress;
      case 'completed':
      case 'hoanthanh':
        return SuggestionStatus.completed;
    case 'rejected':
    case 'tuchoi':
      return SuggestionStatus.rejected;
    default:
      return SuggestionStatus.newSuggestion;
  }
}

String suggestionStatusToDisplay(SuggestionStatus status) {
  switch (status) {
    case SuggestionStatus.newSuggestion:
      return 'Mới';
    case SuggestionStatus.inProgress:
      return 'Đang xử lý';
    case SuggestionStatus.completed:
      return 'Đã hoàn thành';
    case SuggestionStatus.rejected:
      return 'Đã từ chối';
  }
}

// Model cho bài đăng
class CommunityPost {
  final String id;
  final PostType type;
  final String title;
  final String content;
  final String createdById;
  final String createdByName;
  final String? createdByAvatarUrl;
  final String? apartmentCode;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final SuggestionStatus? suggestionStatus; // Chỉ dùng cho kiến nghị
  final bool canEdit;
  final bool canDelete;

  CommunityPost({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdById,
    required this.createdByName,
    this.createdByAvatarUrl,
    this.apartmentCode,
    required this.createdAt,
    this.updatedAt,
    this.imageUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.suggestionStatus,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    // Parse UTC time và chuyển sang local time
    final createdAtStr = (j['createdAtUtc'] ?? j['createdAt']).toString();
    DateTime createdAt;
    try {
      // Nếu có 'Z' hoặc '+00:00' thì parse như UTC, sau đó convert sang local
      if (createdAtStr.endsWith('Z') || createdAtStr.contains('+00:00')) {
        createdAt = DateTime.parse(createdAtStr).toLocal();
      } else {
        // Nếu không có timezone indicator, giả sử là UTC và convert sang local
        createdAt = DateTime.parse(createdAtStr + 'Z').toLocal();
      }
    } catch (e) {
      // Fallback: parse như local time nếu có lỗi
      createdAt = DateTime.parse(createdAtStr);
    }
    
    DateTime? updatedAt;
    if (j['updatedAtUtc'] != null) {
      final updatedAtStr = j['updatedAtUtc'].toString();
      try {
        if (updatedAtStr.endsWith('Z') || updatedAtStr.contains('+00:00')) {
          updatedAt = DateTime.parse(updatedAtStr).toLocal();
        } else {
          updatedAt = DateTime.parse(updatedAtStr + 'Z').toLocal();
        }
      } catch (e) {
        updatedAt = DateTime.tryParse(updatedAtStr);
      }
    }
    
    return CommunityPost(
        id: (j['id'] ?? '').toString(),
        type: postTypeFromString(j['type']?.toString()),
        title: (j['title'] ?? '') as String,
        content: (j['content'] ?? '') as String,
        createdById: (j['createdById'] ?? '') as String,
        createdByName: (j['createdByName'] ?? 'Ẩn danh') as String,
        createdByAvatarUrl: j['createdByAvatarUrl'] as String?,
        apartmentCode: j['apartmentCode'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
        imageUrls: () {
          final imageUrlsValue = j['imageUrls'];
          if (imageUrlsValue == null) return <String>[];
          if (imageUrlsValue is List) {
            return imageUrlsValue.map((e) => e.toString()).toList();
          }
          if (imageUrlsValue is String) {
            // Nếu là string (comma-separated), split ra
            return imageUrlsValue.split(',').where((s) => s.trim().isNotEmpty).toList();
          }
          return <String>[];
        }(),
        likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        isLiked: (j['isLiked'] as bool?) ?? false,
        suggestionStatus: j['suggestionStatus'] != null
            ? suggestionStatusFromString(j['suggestionStatus']?.toString())
            : null,
        canEdit: (j['canEdit'] as bool?) ?? false,
        canDelete: (j['canDelete'] as bool?) ?? false,
      );
  }
}

// Model cho người đã like
class PostLikeUser {
  final String id;
  final String userName;
  final String fullName;
  final String? avatarUrl;

  PostLikeUser({
    required this.id,
    required this.userName,
    required this.fullName,
    this.avatarUrl,
  });

  factory PostLikeUser.fromJson(Map<String, dynamic> j) => PostLikeUser(
        id: (j['id'] ?? '').toString(),
        userName: (j['userName'] ?? 'Unknown') as String,
        fullName: (j['fullName'] ?? j['userName'] ?? 'Unknown') as String,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

// Model cho bình luận
class PostComment {
  final String id;
  final String postId;
  final String? parentCommentId; // ID của comment cha nếu là reply
  final String content;
  final String createdById;
  final String createdByName;
  final String? createdByAvatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isHidden;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool canEdit;
  final bool canDelete;

  PostComment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.content,
    required this.createdById,
    required this.createdByName,
    this.createdByAvatarUrl,
    required this.createdAt,
    this.updatedAt,
    this.isHidden = false,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) {
    // Parse UTC time và chuyển sang local time
    final createdAtStr = (j['createdAtUtc'] ?? j['createdAt']).toString();
    DateTime createdAt;
    try {
      // Nếu có 'Z' hoặc '+00:00' thì parse như UTC, sau đó convert sang local
      if (createdAtStr.endsWith('Z') || createdAtStr.contains('+00:00')) {
        createdAt = DateTime.parse(createdAtStr).toLocal();
      } else {
        // Nếu không có timezone indicator, giả sử là UTC và convert sang local
        createdAt = DateTime.parse(createdAtStr + 'Z').toLocal();
      }
    } catch (e) {
      // Fallback: parse như local time nếu có lỗi
      createdAt = DateTime.parse(createdAtStr);
    }
    
    DateTime? updatedAt;
    if (j['updatedAtUtc'] != null) {
      final updatedAtStr = j['updatedAtUtc'].toString();
      try {
        if (updatedAtStr.endsWith('Z') || updatedAtStr.contains('+00:00')) {
          updatedAt = DateTime.parse(updatedAtStr).toLocal();
        } else {
          updatedAt = DateTime.parse(updatedAtStr + 'Z').toLocal();
        }
      } catch (e) {
        updatedAt = DateTime.tryParse(updatedAtStr);
      }
    }
    
    return PostComment(
      id: (j['id'] ?? '').toString(),
      postId: (j['postId'] ?? '').toString(),
      parentCommentId: j['parentCommentId']?.toString(),
      content: (j['content'] ?? '') as String,
      createdById: (j['createdById'] ?? '') as String,
      createdByName: (j['createdByName'] ?? 'Ẩn danh') as String,
      createdByAvatarUrl: j['createdByAvatarUrl'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isHidden: (j['isHidden'] as bool?) ?? false,
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
      isLiked: (j['isLiked'] as bool?) ?? false,
      canEdit: (j['canEdit'] as bool?) ?? false,
      canDelete: (j['canDelete'] as bool?) ?? false,
    );
  }
}
