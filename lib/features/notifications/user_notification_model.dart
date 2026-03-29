import 'dart:convert';

class UserNotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? refType;
  final String? refId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  // Helper để parse DateTime từ UTC string và đảm bảo nó là UTC
  static DateTime parseUtcDateTime(String dateTimeString) {
    try {
      // Parse và đảm bảo nó là UTC
      final dt = DateTime.parse(dateTimeString);
      // Nếu không phải UTC, chuyển sang UTC
      if (dt.isUtc) {
        return dt;
      } else {
        // Nếu là local time, chuyển sang UTC
        return DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
      }
    } catch (e) {
      // Nếu parse lỗi, trả về UTC now
      return DateTime.now().toUtc();
    }
  }

  UserNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.refType,
    this.refId,
    this.readAt,
  });

  factory UserNotificationModel.fromJson(Map<String, dynamic> j) {
    String fixEncoding(String? s) {
      if (s == null) return '';
      try {
        // Kiểm tra xem có phải là string đã bị double-encode UTF-8 không
        // Các ký tự như "ÄÃ£", "gá»i", "yÃªu", "cáº§u" là dấu hiệu của UTF-8 bị decode sai thành Latin1
        final hasEncodingIssue = s.contains(RegExp(r'[ÄÃáº§á»£Æ°á»áº]')) || 
                                 s.contains('Ã£') || 
                                 s.contains('á»i') ||
                                 s.contains('yÃªu') ||
                                 s.contains('cáº§u');
        
        if (hasEncodingIssue) {
          // Đây là UTF-8 bị decode sai thành Latin1
          // Cần encode lại thành bytes Latin1 rồi decode đúng UTF-8
          try {
            final bytes = latin1.encode(s);
            final fixed = utf8.decode(bytes, allowMalformed: false);
            // Kiểm tra xem đã fix được chưa
            if (!fixed.contains(RegExp(r'[ÄÃáº§á»£Æ°]'))) {
              return fixed;
            }
          } catch (e) {
            // Nếu không decode được, thử cách khác
            try {
              // Thử decode trực tiếp từ codeUnits
              final fixed = String.fromCharCodes(s.codeUnits);
              if (!fixed.contains(RegExp(r'[ÄÃáº§á»£Æ°]'))) {
                return fixed;
              }
            } catch (_) {
              // Bỏ qua
            }
          }
        }
        // Nếu string đã đúng UTF-8, trả về nguyên bản
        return s;
      } catch (_) {
        return s;
      }
    }

    return UserNotificationModel(
      id: j['id'].toString(),
      title: fixEncoding(j['title']?.toString()),
      message: fixEncoding(j['message']?.toString()),
      type: j['type']?.toString() ?? '',
      refType: j['refType']?.toString(),
      refId: j['refId']?.toString(),
      createdAt: parseUtcDateTime(j['createdAtUtc']?.toString() ?? DateTime.now().toUtc().toIso8601String()),
      readAt: j['readAtUtc'] != null ? parseUtcDateTime(j['readAtUtc'].toString()) : null,
    );
  }
}


