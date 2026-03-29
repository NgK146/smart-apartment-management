class VehicleModel {
  final String id;
  final String licensePlate;
  final String vehicleType;
  final String? brand;
  final String? model;
  final String? color;
  final String residentProfileId;
  final bool isActive;
  final String status; // Pending, Approved, Rejected
  final String? rejectionReason;
  final DateTime createdAtUtc;

  VehicleModel({
    required this.id,
    required this.licensePlate,
    required this.vehicleType,
    this.brand,
    this.model,
    this.color,
    required this.residentProfileId,
    required this.isActive,
    this.status = 'Pending',
    this.rejectionReason,
    required this.createdAtUtc,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> j) => VehicleModel(
        id: j['id'],
        licensePlate: j['licensePlate'],
        vehicleType: j['vehicleType'],
        brand: j['brand'],
        model: j['model'],
        color: j['color'],
        residentProfileId: j['residentProfileId'],
        isActive: j['isActive'] ?? true,
        status: j['status'] ?? 'Pending',
        rejectionReason: j['rejectionReason'],
        createdAtUtc: DateTime.parse(j['createdAtUtc']),
      );

  Map<String, dynamic> toJson() => {
        'licensePlate': licensePlate,
        'vehicleType': vehicleType,
        'brand': brand,
        'model': model,
        'color': color,
        'isActive': isActive,
        'status': status,
      };

  String get statusText {
    switch (status) {
      case 'Pending':
        return 'Chờ duyệt';
      case 'Approved':
        return 'Đã duyệt';
      case 'Rejected':
        return 'Đã từ chối';
      default:
        return status;
    }
  }

  bool get canEdit => status == 'Pending';
  bool get canBuyPass => status == 'Approved';
}


