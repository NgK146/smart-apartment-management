import '../../core/api_client.dart';

class Apartment {
  final String id;
  final String code;
  final String building;
  final int floor;
  final double? areaM2;
  final String? status; // Available, Occupied, Maintenance, Reserved

  Apartment({required this.id, required this.code, required this.building, required this.floor, this.areaM2, this.status});

  factory Apartment.fromJson(Map<String, dynamic> j) {
    // Parse status: có thể là string ("Available", "Occupied") hoặc số (0,1,2,3)
    String? statusStr;
    final statusValue = j['status'];
    if (statusValue == null) {
      statusStr = null;
    } else if (statusValue is String) {
      statusStr = statusValue;
    } else if (statusValue is int) {
      // Map enum number to string
      switch (statusValue) {
        case 0: statusStr = 'Available'; break;
        case 1: statusStr = 'Occupied'; break;
        case 2: statusStr = 'Maintenance'; break;
        case 3: statusStr = 'Reserved'; break;
        default: statusStr = null;
      }
    } else {
      statusStr = statusValue.toString();
    }
    
    return Apartment(
      id: j['id'].toString(),
      code: j['code'].toString(),
      building: j['building'].toString(),
      floor: j['floor'] as int? ?? 0,
      areaM2: (j['areaM2'] as num?)?.toDouble(),
      status: statusStr,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'building': building,
    'floor': floor,
    if (areaM2 != null) 'areaM2': areaM2,
    'status': status ?? 'Available', // Default to Available
  };
}

class ApartmentsService {
  Future<List<Apartment>> list({int page = 1, int pageSize = 50, String? search}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final res = await api.dio.get('/api/Apartments', queryParameters: queryParams);
    final items = (res.data['items'] as List).map((e) => Apartment.fromJson(Map<String, dynamic>.from(e))).toList();
    return items;
  }

  Future<Apartment> create(Apartment a) async {
    final res = await api.dio.post('/api/Apartments', data: a.toJson());
    return Apartment.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> update(String id, Apartment a) async {
    await api.dio.put('/api/Apartments/$id', data: a.toJson());
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/api/Apartments/$id');
  }

  // Lấy danh sách căn hộ available cho dropdown (public, không cần đăng nhập)
  Future<List<Apartment>> getAvailable() async {
    final res = await api.dio.get('/api/Apartments/available');
    final items = (res.data as List).map((e) => Apartment.fromJson(Map<String, dynamic>.from(e))).toList();
    return items;
  }

  // Lấy danh sách tất cả căn hộ với status đầy đủ (cho Resident)
  Future<List<Apartment>> listForResident({int page = 1, int pageSize = 200, String? search}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final res = await api.dio.get('/api/Apartments/list', queryParameters: queryParams);
    final items = (res.data['items'] as List).map((e) => Apartment.fromJson(Map<String, dynamic>.from(e))).toList();
    return items;
  }
}

