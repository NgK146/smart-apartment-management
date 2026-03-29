class FeeDefinitionModel {
  final String id;
  final String name;
  final String? description;
  final double amount;
  final String calculationMethod; // Fixed, PerM2, PerUnit, Metered
  final String periodType; // Monthly, Quarterly, Yearly
  final bool isActive;
  final DateTime createdAtUtc;

  FeeDefinitionModel({
    required this.id,
    required this.name,
    this.description,
    required this.amount,
    required this.calculationMethod,
    required this.periodType,
    required this.isActive,
    required this.createdAtUtc,
  });

  factory FeeDefinitionModel.fromJson(Map<String, dynamic> json) => FeeDefinitionModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        amount: (json['amount'] as num).toDouble(),
        calculationMethod: json['calculationMethod']?.toString() ?? 'Fixed',
        periodType: json['periodType']?.toString() ?? 'Monthly',
        isActive: json['isActive'] ?? true,
        createdAtUtc: DateTime.parse(json['createdAtUtc']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'amount': amount,
        'calculationMethod': calculationMethod,
        'periodType': periodType,
        'isActive': isActive,
      };

  String get calculationMethodText {
    switch (calculationMethod) {
      case 'Fixed': return 'Cố định';
      case 'PerM2': return 'Theo m²';
      case 'PerUnit': return 'Theo đơn vị';
      case 'Metered': return 'Theo chỉ số';
      default: return calculationMethod;
    }
  }

  String get periodTypeText {
    switch (periodType) {
      case 'Monthly': return 'Hàng tháng';
      case 'Quarterly': return 'Hàng quý';
      case 'Yearly': return 'Hàng năm';
      default: return periodType;
    }
  }
}

