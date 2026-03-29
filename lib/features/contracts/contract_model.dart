class RentalContractModel {
  final String id;
  final String contractNumber;
  final String apartmentId;
  final String residentProfileId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double deposit;
  final String? terms;
  final String status;
  final DateTime? signedAtUtc;
  final String? documentUrl;
  final DateTime createdAtUtc;

  RentalContractModel({
    required this.id,
    required this.contractNumber,
    required this.apartmentId,
    required this.residentProfileId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.deposit,
    this.terms,
    required this.status,
    this.signedAtUtc,
    this.documentUrl,
    required this.createdAtUtc,
  });

  factory RentalContractModel.fromJson(Map<String, dynamic> j) => RentalContractModel(
        id: j['id'],
        contractNumber: j['contractNumber'],
        apartmentId: j['apartmentId'],
        residentProfileId: j['residentProfileId'],
        startDate: DateTime.parse(j['startDate']),
        endDate: DateTime.parse(j['endDate']),
        monthlyRent: (j['monthlyRent'] as num).toDouble(),
        deposit: (j['deposit'] as num).toDouble(),
        terms: j['terms'],
        status: j['status'].toString(),
        signedAtUtc: j['signedAtUtc'] != null ? DateTime.parse(j['signedAtUtc']) : null,
        documentUrl: j['documentUrl'],
        createdAtUtc: DateTime.parse(j['createdAtUtc']),
      );
}


