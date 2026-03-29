import 'package:flutter/material.dart';

class ParkingPassModel {
  final String id;
  final String vehicleId;
  final String? vehicleLicensePlate;
  final String parkingPlanId;
  final String? parkingPlanName;
  final String passCode;
  final DateTime validFrom;
  final DateTime validTo;
  final String status; // PendingPayment, Active, Expired, Revoked
  final String? invoiceId;
  final DateTime? activatedAt;
  final String? revocationReason;
  final DateTime createdAtUtc;

  ParkingPassModel({
    required this.id,
    required this.vehicleId,
    this.vehicleLicensePlate,
    required this.parkingPlanId,
    this.parkingPlanName,
    required this.passCode,
    required this.validFrom,
    required this.validTo,
    required this.status,
    this.invoiceId,
    this.activatedAt,
    this.revocationReason,
    required this.createdAtUtc,
  });

  factory ParkingPassModel.fromJson(Map<String, dynamic> j) => ParkingPassModel(
        id: j['id'],
        vehicleId: j['vehicleId'],
        vehicleLicensePlate: j['vehicle']?['licensePlate'],
        parkingPlanId: j['parkingPlanId'],
        parkingPlanName: j['parkingPlan']?['name'],
        passCode: j['passCode'],
        validFrom: DateTime.parse(j['validFrom']),
        validTo: DateTime.parse(j['validTo']),
        status: j['status'] ?? 'PendingPayment',
        invoiceId: j['invoiceId'],
        activatedAt: j['activatedAt'] != null ? DateTime.parse(j['activatedAt']) : null,
        revocationReason: j['revocationReason'],
        createdAtUtc: DateTime.parse(j['createdAtUtc']),
      );

  bool get isActive => status == 'Active';
  bool get isExpired => status == 'Expired' || DateTime.now().isAfter(validTo);
  bool get isPendingPayment => status == 'PendingPayment';
  bool get isRevoked => status == 'Revoked';

  int get daysRemaining {
    if (isExpired || !isActive) return 0;
    final remaining = validTo.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  String get statusText {
    switch (status) {
      case 'PendingPayment':
        return 'Chờ thanh toán';
      case 'Active':
        return 'Đang hoạt động';
      case 'Expired':
        return 'Đã hết hạn';
      case 'Revoked':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'PendingPayment':
        return Colors.orange;
      case 'Active':
        return Colors.green;
      case 'Expired':
        return Colors.grey;
      case 'Revoked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get needsRenewal => isActive && daysRemaining <= 3;
}

