class ServiceProviderModel {
  final String id;
  final String name;
  final String category;
  final String? phone;
  final String? email;
  final String? address;
  final String? description;
  final bool isActive;

  ServiceProviderModel({
    required this.id,
    required this.name,
    required this.category,
    this.phone,
    this.email,
    this.address,
    this.description,
    required this.isActive,
  });

  factory ServiceProviderModel.fromJson(Map<String, dynamic> j) => ServiceProviderModel(
        id: j['id'],
        name: j['name'],
        category: j['category'],
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        description: j['description'],
        isActive: j['isActive'] ?? true,
      );
}


