// Model cho Cửa hàng / Gian hàng
class Store {
  final int id;
  final String name;
  final String? description;
  final String? phone;
  final String? logoUrl;
  final String? coverImageUrl;
  final bool isApproved;
  final bool isActive;
  final String ownerId;
  final double? averageRating;
  final int? totalReviews;

  Store({
    required this.id,
    required this.name,
    this.description,
    this.phone,
    this.logoUrl,
    this.coverImageUrl,
    required this.isApproved,
    required this.isActive,
    required this.ownerId,
    this.averageRating,
    this.totalReviews,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? json['Id'] ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      description: json['description'] ?? json['Description'],
      phone: json['phone'] ?? json['Phone'],
      logoUrl: json['logoUrl'] ?? json['LogoUrl'],
      coverImageUrl: json['coverImageUrl'] ?? json['CoverImageUrl'],
      isApproved: json['isApproved'] ?? json['IsApproved'] ?? false,
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
      ownerId: json['ownerId'] ?? json['OwnerId'] ?? '',
      averageRating: json['averageRating'] ?? json['AverageRating'] != null
          ? (json['averageRating'] ?? json['AverageRating']).toDouble()
          : null,
      totalReviews: json['totalReviews'] ?? json['TotalReviews'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phone': phone,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'isApproved': isApproved,
      'isActive': isActive,
      'ownerId': ownerId,
    };
  }
}

