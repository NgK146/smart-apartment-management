// Models cho dịch vụ Concierge/Lễ tân
class ConciergeService {
  final String id;
  final String name;
  final String description;
  final String icon; // Icon name hoặc emoji
  final ServiceCategory category;
  final bool isAvailable;
  final int? estimatedMinutes; // Thời gian ước tính

  ConciergeService({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.isAvailable = true,
    this.estimatedMinutes,
  });

  factory ConciergeService.fromJson(Map<String, dynamic> json) {
    return ConciergeService(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      category: ServiceCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => ServiceCategory.other,
      ),
      isAvailable: json['isAvailable'] as bool? ?? true,
      estimatedMinutes: json['estimatedMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'category': category.toString().split('.').last,
      'isAvailable': isAvailable,
      'estimatedMinutes': estimatedMinutes,
    };
  }
}

enum ServiceCategory {
  housekeeping, // Dọn phòng
  laundry, // Giặt ủi
  maintenance, // Sửa chữa
  transportation, // Taxi, xe
  security, // Bảo vệ
  concierge, // Lễ tân
  other,
}

class ConciergeRequest {
  final String id;
  final String serviceId;
  final String serviceName;
  final String? userId;
  final String? userName;
  final String? notes;
  final DateTime? scheduledForUtc;
  final DateTime createdAtUtc;
  final ConciergeRequestStatus status;

  ConciergeRequest({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    this.userId,
    this.userName,
    this.notes,
    this.scheduledForUtc,
    required this.createdAtUtc,
    this.status = ConciergeRequestStatus.pending,
  });

  factory ConciergeRequest.fromJson(Map<String, dynamic> json) {
    return ConciergeRequest(
      id: json['id'] as String,
      serviceId: json['serviceId'] as String,
      serviceName: (json['serviceName'] ?? '') as String,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      notes: json['notes'] as String?,
      scheduledForUtc: json['scheduledForUtc'] != null
          ? DateTime.parse(json['scheduledForUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(
          (json['createdAtUtc'] ?? json['requestedAt'] ?? DateTime.now().toIso8601String())
              as String),
      status: ConciergeRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() ==
            (json['status'] as String).toLowerCase(),
        orElse: () => ConciergeRequestStatus.pending,
      ),
    );
  }
}

enum ConciergeRequestStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}



