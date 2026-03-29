// Model cho Đánh giá Cửa hàng
class StoreReview {
  final int id;
  final int rating; // 1-5 sao
  final String? comment;
  final DateTime createdAtUtc;
  final int storeId;
  final String residentId;
  final String? residentName;
  final int? orderId;

  StoreReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAtUtc,
    required this.storeId,
    required this.residentId,
    this.residentName,
    this.orderId,
  });

  factory StoreReview.fromJson(Map<String, dynamic> json) {
    DateTime createdAt = DateTime.now();
    if (json['createdAtUtc'] != null || json['CreatedAtUtc'] != null) {
      try {
        final dateStr = json['createdAtUtc'] ?? json['CreatedAtUtc'];
        if (dateStr is String) {
          createdAt = DateTime.parse(dateStr);
        } else if (dateStr is DateTime) {
          createdAt = dateStr;
        }
      } catch (_) {}
    }

    return StoreReview(
      id: json['id'] ?? json['Id'] ?? 0,
      rating: json['rating'] ?? json['Rating'] ?? 0,
      comment: json['comment'] ?? json['Comment'],
      createdAtUtc: createdAt,
      storeId: json['storeId'] ?? json['StoreId'] ?? 0,
      residentId: json['residentId'] ?? json['ResidentId'] ?? '',
      residentName: json['residentName'] ?? json['ResidentName'],
      orderId: json['orderId'] ?? json['OrderId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rating': rating,
      'comment': comment,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'storeId': storeId,
      'residentId': residentId,
      'orderId': orderId,
    };
  }
}

