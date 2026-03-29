// Models cho Visitor Access & QR
class VisitorAccess {
  final String id;
  final String residentId;
  final String apartmentCode;
  final String visitorName;
  final String? visitorPhone;
  final String? visitorEmail;
  final DateTime visitDate;
  final String? visitTime; // "14:00" format
  final String? purpose;
  final String qrCode; // QR code string
  final String qrCodeUrl; // URL để generate QR
  final AccessStatus status;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime createdAt;
  final DateTime expiresAt;

  VisitorAccess({
    required this.id,
    required this.residentId,
    required this.apartmentCode,
    required this.visitorName,
    this.visitorPhone,
    this.visitorEmail,
    required this.visitDate,
    this.visitTime,
    this.purpose,
    required this.qrCode,
    required this.qrCodeUrl,
    this.status = AccessStatus.pending,
    this.checkedInAt,
    this.checkedOutAt,
    required this.createdAt,
    required this.expiresAt,
  });

  factory VisitorAccess.fromJson(Map<String, dynamic> json) {
    return VisitorAccess(
      id: json['id'] as String,
      residentId: json['residentId'] as String,
      apartmentCode: json['apartmentCode'] as String,
      visitorName: json['visitorName'] as String,
      visitorPhone: json['visitorPhone'] as String?,
      visitorEmail: json['visitorEmail'] as String?,
      visitDate: DateTime.parse(json['visitDate'] as String),
      visitTime: json['visitTime'] as String?,
      purpose: json['purpose'] as String?,
      qrCode: json['qrCode'] as String,
      qrCodeUrl: json['qrCodeUrl'] as String,
      status: AccessStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AccessStatus.pending,
      ),
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'] as String)
          : null,
      checkedOutAt: json['checkedOutAt'] != null
          ? DateTime.parse(json['checkedOutAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentId': residentId,
      'apartmentCode': apartmentCode,
      'visitorName': visitorName,
      'visitorPhone': visitorPhone,
      'visitorEmail': visitorEmail,
      'visitDate': visitDate.toIso8601String(),
      'visitTime': visitTime,
      'purpose': purpose,
      'qrCode': qrCode,
      'qrCodeUrl': qrCodeUrl,
      'status': status.toString().split('.').last,
      'checkedInAt': checkedInAt?.toIso8601String(),
      'checkedOutAt': checkedOutAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canCheckIn => status == AccessStatus.pending && !isExpired;
}

enum AccessStatus {
  pending,
  checkedIn,
  checkedOut,
  expired,
  cancelled,
}



