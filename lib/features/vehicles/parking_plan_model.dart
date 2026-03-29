class ParkingPlanModel {
  final String id;
  final String name;
  final String? description;
  final String vehicleType;
  final double price;
  final int durationInDays;
  final bool isActive;
  final DateTime createdAtUtc;

  ParkingPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.vehicleType,
    required this.price,
    required this.durationInDays,
    required this.isActive,
    required this.createdAtUtc,
  });

  factory ParkingPlanModel.fromJson(Map<String, dynamic> j) => ParkingPlanModel(
        id: j['id'],
        name: j['name'],
        description: j['description'],
        vehicleType: j['vehicleType'],
        price: (j['price'] as num).toDouble(),
        durationInDays: j['durationInDays'],
        isActive: j['isActive'] ?? true,
        createdAtUtc: DateTime.parse(j['createdAtUtc']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'vehicleType': vehicleType,
        'price': price,
        'durationInDays': durationInDays,
        'isActive': isActive,
      };

  String get formattedPrice => '${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )} đ';

  String get durationText {
    if (durationInDays >= 365) {
      final years = (durationInDays / 365).floor();
      return '$years ${years == 1 ? 'năm' : 'năm'}';
    } else if (durationInDays >= 30) {
      final months = (durationInDays / 30).floor();
      return '$months ${months == 1 ? 'tháng' : 'tháng'}';
    } else {
      return '$durationInDays ngày';
    }
  }
}

