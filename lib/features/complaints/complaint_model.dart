class ComplaintModel {
  final String id;
  final String title;
  final String content;
  final String category;
  final String status;
  final String? mediaUrls;
  final DateTime createdAtUtc;
  final String? createdBy;
  final String? emailNguoiGui;
  final String? tenNguoiGui;
  final String? phanHoiAdmin;
  final DateTime? ngayCapNhat;
  final List<CommentModel>? comments;

  ComplaintModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.status,
    this.mediaUrls,
    required this.createdAtUtc,
    this.createdBy,
    this.emailNguoiGui,
    this.tenNguoiGui,
    this.phanHoiAdmin,
    this.ngayCapNhat,
    this.comments,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> j) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is DateTime) {
          return value;
        } else {
          return DateTime.parse(value.toString());
        }
      } catch (e) {
        return DateTime.now();
      }
    }

    DateTime? parseDateTimeNullable(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is DateTime) {
          return value;
        } else {
          return DateTime.parse(value.toString());
        }
      } catch (e) {
        return null;
      }
    }

    return ComplaintModel(
      id: (j['id'] ?? j['Id'] ?? '').toString(),
      title: (j['title'] ?? j['tieuDe'] ?? j['Title'] ?? '').toString(),
      content: (j['content'] ?? j['noiDung'] ?? j['Content'] ?? '').toString(),
      category: (j['category'] ?? j['loaiPhanAnh'] ?? j['Category'] ?? 'Other').toString(),
      status: (j['status'] ?? j['trangThai'] ?? j['Status'] ?? 'Pending').toString(),
      mediaUrls: j['mediaUrls']?.toString(),
      createdAtUtc: parseDateTime(j['createdAtUtc'] ?? j['ngayGui'] ?? DateTime.now()),
      createdBy: j['createdBy']?.toString(),
      emailNguoiGui: j['emailNguoiGui']?.toString(),
      tenNguoiGui: j['tenNguoiGui']?.toString(),
      phanHoiAdmin: j['phanHoiAdmin']?.toString(),
      ngayCapNhat: parseDateTimeNullable(j['ngayCapNhat']),
      comments: j['comments'] != null 
          ? (j['comments'] as List).map((c) => CommentModel.fromJson(Map<String, dynamic>.from(c))).toList()
          : null,
    );
  }
}

class CommentModel {
  final String id;
  final String message;
  final String userId;
  final String? userName;
  final bool? isAdmin;
  final DateTime createdAtUtc;

  CommentModel({
    required this.id,
    required this.message,
    required this.userId,
    this.userName,
    this.isAdmin,
    required this.createdAtUtc,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is DateTime) {
          return value;
        } else {
          return DateTime.parse(value.toString());
        }
      } catch (e) {
        return DateTime.now();
      }
    }

    return CommentModel(
      id: (j['id'] ?? '').toString(),
      message: (j['message'] ?? '').toString(),
      userId: (j['userId'] ?? '').toString(),
      userName: j['userName']?.toString(),
      isAdmin: j['isAdmin'] as bool?,
      createdAtUtc: parseDateTime(j['createdAtUtc'] ?? j['ngayGui'] ?? DateTime.now()),
    );
  }
}