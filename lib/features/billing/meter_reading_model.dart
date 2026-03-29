class MeterReadingModel {
  final String id;
  final int month;
  final int year;
  final double reading;
  final double previousReading;
  final double usage; // reading - previousReading
  final String apartmentId;
  final String? apartmentCode;
  final String feeDefinitionId;
  final String? feeDefinitionName;
  final DateTime createdAtUtc;

  MeterReadingModel({
    required this.id,
    required this.month,
    required this.year,
    required this.reading,
    required this.previousReading,
    required this.usage,
    required this.apartmentId,
    this.apartmentCode,
    required this.feeDefinitionId,
    this.feeDefinitionName,
    required this.createdAtUtc,
  });

  factory MeterReadingModel.fromJson(Map<String, dynamic> json) => MeterReadingModel(
        id: json['id'],
        month: json['month'],
        year: json['year'],
        reading: (json['reading'] as num).toDouble(),
        previousReading: (json['previousReading'] as num).toDouble(),
        usage: (json['usage'] as num? ?? (json['reading'] as num).toDouble() - (json['previousReading'] as num).toDouble()).toDouble(),
        apartmentId: json['apartmentId'],
        apartmentCode: json['apartment']?['code'],
        feeDefinitionId: json['feeDefinitionId'],
        feeDefinitionName: json['feeDefinition']?['name'],
        createdAtUtc: DateTime.parse(json['createdAtUtc']),
      );

  Map<String, dynamic> toJson() => {
        'apartmentId': apartmentId,
        'feeDefinitionId': feeDefinitionId,
        'reading': reading,
      };
}

