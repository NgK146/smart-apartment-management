class NotificationModel {
  final String id, title, content, type;
  final DateTime createdAt;
  final DateTime? effectiveFrom, effectiveTo;
  final String? postId; // ID của CommunityPost liên quan
  final int likeCount; // Số lượt like
  final int commentCount; // Số lượt bình luận
  
  NotificationModel({
    required this.id, 
    required this.title, 
    required this.content, 
    required this.type, 
    required this.createdAt, 
    this.effectiveFrom, 
    this.effectiveTo,
    this.postId,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
    id: j['id'], 
    title: j['title'], 
    content: j['content'],
    type: j['type'].toString(), 
    createdAt: DateTime.parse(j['createdAtUtc'] ?? j['createdAt'] ?? DateTime.now().toIso8601String()),
    effectiveFrom: j['effectiveFrom'] != null ? DateTime.parse(j['effectiveFrom']) : null,
    effectiveTo: j['effectiveTo'] != null ? DateTime.parse(j['effectiveTo']) : null,
    postId: j['postId']?.toString(),
    likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'type': type,
    if (effectiveFrom != null) 'effectiveFrom': effectiveFrom!.toUtc().toIso8601String(),
    if (effectiveTo != null) 'effectiveTo': effectiveTo!.toUtc().toIso8601String(),
  };
}
