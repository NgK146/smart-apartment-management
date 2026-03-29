// Models cho Smart Devices: Barrier, Locker, EV Charging
class SmartBarrier {
  final String id;
  final String name; // "Cổng chính", "Cổng phụ"
  final BarrierType type;
  final String location;
  final BarrierStatus status;
  final DateTime? lastAccessAt;
  final String? lastAccessBy;

  SmartBarrier({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.status = BarrierStatus.normal,
    this.lastAccessAt,
    this.lastAccessBy,
  });

  factory SmartBarrier.fromJson(Map<String, dynamic> json) {
    return SmartBarrier(
      id: json['id'] as String,
      name: json['name'] as String,
      type: BarrierType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => BarrierType.entrance,
      ),
      location: json['location'] as String,
      status: BarrierStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => BarrierStatus.normal,
      ),
      lastAccessAt: json['lastAccessAt'] != null
          ? DateTime.parse(json['lastAccessAt'] as String)
          : null,
      lastAccessBy: json['lastAccessBy'] as String?,
    );
  }
}

enum BarrierType {
  entrance, // Cổng vào
  exit, // Cổng ra
  parking, // Cổng bãi xe
}

enum BarrierStatus {
  normal,
  maintenance,
  blocked,
}

class SmartLocker {
  final String id;
  final String name; // "Locker A01"
  final String location;
  final LockerSize size;
  final LockerStatus status;
  final String? currentResidentId;
  final String? currentPackageId;
  final DateTime? occupiedAt;
  final DateTime? collectedAt;
  final String? otpCode; // OTP để mở locker

  SmartLocker({
    required this.id,
    required this.name,
    required this.location,
    required this.size,
    this.status = LockerStatus.available,
    this.currentResidentId,
    this.currentPackageId,
    this.occupiedAt,
    this.collectedAt,
    this.otpCode,
  });

  factory SmartLocker.fromJson(Map<String, dynamic> json) {
    return SmartLocker(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      size: LockerSize.values.firstWhere(
        (e) => e.toString().split('.').last == json['size'],
        orElse: () => LockerSize.medium,
      ),
      status: LockerStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => LockerStatus.available,
      ),
      currentResidentId: json['currentResidentId'] as String?,
      currentPackageId: json['currentPackageId'] as String?,
      occupiedAt: json['occupiedAt'] != null
          ? DateTime.parse(json['occupiedAt'] as String)
          : null,
      collectedAt: json['collectedAt'] != null
          ? DateTime.parse(json['collectedAt'] as String)
          : null,
      otpCode: json['otpCode'] as String?,
    );
  }

  bool get isAvailable => status == LockerStatus.available;
}

enum LockerSize {
  small, // < 30cm
  medium, // 30-50cm
  large, // > 50cm
}

enum LockerStatus {
  available,
  occupied,
  maintenance,
  reserved,
}

class EVChargingStation {
  final String id;
  final String name; // "EV Station 01"
  final String location;
  final ChargingType type;
  final ChargingStatus status;
  final double? currentPower; // kW
  final double? totalEnergy; // kWh đã sạc
  final String? currentResidentId;
  final DateTime? chargingStartAt;
  final DateTime? chargingEndAt;
  final double? costPerKwh;

  EVChargingStation({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    this.status = ChargingStatus.available,
    this.currentPower,
    this.totalEnergy,
    this.currentResidentId,
    this.chargingStartAt,
    this.chargingEndAt,
    this.costPerKwh,
  });

  factory EVChargingStation.fromJson(Map<String, dynamic> json) {
    return EVChargingStation(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      type: ChargingType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ChargingType.slow,
      ),
      status: ChargingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => ChargingStatus.available,
      ),
      currentPower: (json['currentPower'] as num?)?.toDouble(),
      totalEnergy: (json['totalEnergy'] as num?)?.toDouble(),
      currentResidentId: json['currentResidentId'] as String?,
      chargingStartAt: json['chargingStartAt'] != null
          ? DateTime.parse(json['chargingStartAt'] as String)
          : null,
      chargingEndAt: json['chargingEndAt'] != null
          ? DateTime.parse(json['chargingEndAt'] as String)
          : null,
      costPerKwh: (json['costPerKwh'] as num?)?.toDouble(),
    );
  }

  bool get isAvailable => status == ChargingStatus.available;
  bool get isCharging => status == ChargingStatus.charging;
}

enum ChargingType {
  slow, // AC slow charging
  fast, // DC fast charging
}

enum ChargingStatus {
  available,
  charging,
  maintenance,
  reserved,
}



