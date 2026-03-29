import 'enums.dart';

class LockerTransaction {
  final String id;
  final String apartmentId;
  final String? apartmentCode;
  final String compartmentId;
  final String? compartmentCode;
  final LockerTransactionStatus status;
  final DateTime? dropTime;
  final DateTime? pickupTime;
  final DateTime? pickupTokenExpireAt;
  final String? notes;
  final DateTime createdAtUtc;

  LockerTransaction({
    required this.id,
    required this.apartmentId,
    this.apartmentCode,
    required this.compartmentId,
    this.compartmentCode,
    required this.status,
    this.dropTime,
    this.pickupTime,
    this.pickupTokenExpireAt,
    this.notes,
    required this.createdAtUtc,
  });

  factory LockerTransaction.fromJson(Map<String, dynamic> json) {
    return LockerTransaction(
      id: json['id'] as String,
      apartmentId: json['apartmentId'] as String,
      apartmentCode: json['apartmentCode'] as String?,
      compartmentId: json['compartmentId'] as String,
      compartmentCode: json['compartmentCode'] as String?,
      status: LockerTransactionStatus.fromString(json['status'] as String),
      dropTime: json['dropTime'] != null
          ? DateTime.parse(json['dropTime'] as String)
          : null,
      pickupTime: json['pickupTime'] != null
          ? DateTime.parse(json['pickupTime'] as String)
          : null,
      pickupTokenExpireAt: json['pickupTokenExpireAt'] != null
          ? DateTime.parse(json['pickupTokenExpireAt'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartmentId': apartmentId,
      'apartmentCode': apartmentCode,
      'compartmentId': compartmentId,
      'compartmentCode': compartmentCode,
      'status': status.name,
      'dropTime': dropTime?.toIso8601String(),
      'pickupTime': pickupTime?.toIso8601String(),
      'pickupTokenExpireAt': pickupTokenExpireAt?.toIso8601String(),
      'notes': notes,
      'createdAtUtc': createdAtUtc.toIso8601String(),
    };
  }

  bool get isExpired {
    if (pickupTokenExpireAt == null) return false;
    return DateTime.now().isAfter(pickupTokenExpireAt!);
  }

  bool get canPickup {
    return status == LockerTransactionStatus.stored && !isExpired;
  }
}
