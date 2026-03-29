class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String amenityName;
  final String userId;
  final String userName;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String status;
  final double? price;
  final String? invoiceId;

  AmenityBookingModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.userId,
    required this.userName,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.status,
    this.price,
    this.invoiceId,
  });

  factory AmenityBookingModel.fromJson(Map<String, dynamic> j) {
    final amenity = j['amenity'] as Map<String, dynamic>?;
    return AmenityBookingModel(
      id: j['id'].toString(),
      amenityId: j['amenityId'].toString(),
      amenityName: amenity?['name']?.toString() ?? j['amenityName']?.toString() ?? '',
      userId: j['userId'].toString(),
      userName: j['userName']?.toString() ?? 'Unknown',
      startTimeUtc: DateTime.parse(j['startTimeUtc']),
      endTimeUtc: DateTime.parse(j['endTimeUtc']),
      status: j['status'].toString(),
      price: (j['price'] as num?)?.toDouble(),
      invoiceId: j['invoiceId']?.toString(),
    );
  }
}

