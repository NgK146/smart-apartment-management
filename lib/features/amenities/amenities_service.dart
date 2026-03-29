import '../../core/api_client.dart';
import 'amenity_model.dart';
import 'amenity_booking_model.dart';

class AmenitiesService {
  Future<List<Amenity>> list({int page=1, int pageSize=50, String? search, String? category}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    final res = await api.dio.get('/api/Amenities', queryParameters: queryParams);
    return (res.data['items'] as List).map((e)=> Amenity.fromJson(Map<String,dynamic>.from(e))).toList();
  }

  Future<Amenity> get(String id) async {
    final res = await api.dio.get('/api/Amenities/$id');
    return Amenity.fromJson(Map<String,dynamic>.from(res.data));
  }

  Future<Map<String, dynamic>> book({
    required String amenityId, 
    required DateTime start, 
    required DateTime end, 
    double? price,
    String? purpose,
    int? participantCount,
    String? contactPhone,
    String? transactionRef,
    bool? paid,
    int? reminderOffsetMinutes,
  }) async {
    final res = await api.dio.post('/api/AmenityBookings', data: {
      'amenityId': amenityId, 
      'startTimeUtc': start.toUtc().toIso8601String(), 
      'endTimeUtc': end.toUtc().toIso8601String(), 
      'price': price,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      if (participantCount != null) 'participantCount': participantCount,
      if (contactPhone != null && contactPhone.isNotEmpty) 'contactPhone': contactPhone,
      if (transactionRef != null && transactionRef.isNotEmpty) 'transactionRef': transactionRef,
      if (paid != null) 'paid': paid,
      if (reminderOffsetMinutes != null) 'reminderOffsetMinutes': reminderOffsetMinutes,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<AmenityBookingModel> getBooking(String id) async {
    final res = await api.dio.get('/api/AmenityBookings/$id');
    return AmenityBookingModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<List<Map<String, dynamic>>> availability({required String amenityId, required DateTime weekStartUtc, int slotMinutes = 60, int dayStart = 6, int dayEnd = 22}) async {
    final res = await api.dio.get('/api/AmenityBookings/availability', queryParameters: {
      'amenityId': amenityId,
      'weekStartUtc': weekStartUtc.toUtc().toIso8601String(),
      'slotMinutes': slotMinutes,
      'dayStart': dayStart,
      'dayEnd': dayEnd,
    });
    final items = (res.data['items'] as List).map((e)=> Map<String,dynamic>.from(e)).toList();
    return items;
  }

  // ========== ADMIN ==========
  Future<Amenity> create(Amenity m) async {
    // Đảm bảo category được gửi lên server
    final data = m.toJson();
    if (data['category'] == null || (data['category'] as String).isEmpty) {
      throw Exception('Category không được để trống');
    }
    final res = await api.dio.post('/api/Amenities', data: data);
    return Amenity.fromJson(Map<String,dynamic>.from(res.data));
  }

  Future<void> update(String id, Amenity m) async {
    // Đảm bảo category được gửi lên server
    final data = m.toJson();
    if (data['category'] == null || (data['category'] as String).isEmpty) {
      throw Exception('Category không được để trống');
    }
    await api.dio.put('/api/Amenities/$id', data: data);
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/api/Amenities/$id');
  }

  /// Lấy danh sách categories từ backend
  Future<List<String>> getCategories() async {
    try {
      // Thử lấy từ endpoint mới /api/Categories/names
      final res = await api.dio.get('/api/Categories/names');
      if (res.data is List) {
        final categories = (res.data as List).map((e) => e.toString()).toList();
        if (categories.isNotEmpty) return categories;
      }
    } catch (e) {
      // Nếu endpoint mới không có, thử endpoint cũ
      try {
        final res = await api.dio.get('/api/Amenities/categories');
        if (res.data is List) {
          final categories = (res.data as List).map((e) => e.toString()).toList();
          if (categories.isNotEmpty) return categories;
        }
      } catch (_) {
        // Nếu cả hai endpoint đều không có, dùng danh sách mặc định
      }
    }
    // Fallback về danh sách mặc định
    return defaultCategories;
  }

  /// Danh sách categories mặc định cho chung cư cao cấp
  static const List<String> defaultCategories = [
    'Thể thao & Fitness',
    'Giải trí',
    'Ăn uống',
    'Spa & Wellness',
    'Hồ bơi',
    'Khu vui chơi trẻ em',
    'Phòng họp & Sự kiện',
    'Thư viện',
    'Karaoke',
    'Sân tennis',
    'Sân bóng rổ',
    'Phòng gym',
    'Yoga & Pilates',
    'BBQ & Nướng',
    'Khu vườn',
    'Khác',
  ];

  // ========== ADMIN - Booking Management ==========
  Future<List<AmenityBookingModel>> listBookings({
    int page = 1,
    int pageSize = 50,
    String? status,
    String? amenityId,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (status != null) queryParams['status'] = status;
    if (amenityId != null) queryParams['amenityId'] = amenityId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final res = await api.dio.get('/api/AmenityBookings', queryParameters: queryParams);
    final items = (res.data['items'] as List).map((e)=> AmenityBookingModel.fromJson(Map<String,dynamic>.from(e))).toList();
    return items;
  }

  Future<void> approve(String bookingId) async {
    await api.dio.put('/api/AmenityBookings/$bookingId/approve');
  }

  Future<void> reject(String bookingId) async {
    await api.dio.put('/api/AmenityBookings/$bookingId/reject');
  }

  Future<int> countMyBookings({String? status, bool upcomingOnly = false}) async {
    final queryParams = <String, dynamic>{'page': 1, 'pageSize': 50};
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/AmenityBookings', queryParameters: queryParams);
    final items = (res.data['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    if (!upcomingOnly) {
      final total = res.data['total'];
      if (total is int) return total;
      return items.length;
    }
    final nowUtc = DateTime.now().toUtc();
    final count = items.where((item) {
      final startStr = item['startTimeUtc']?.toString();
      if (startStr == null) return false;
      final start = DateTime.tryParse(startStr);
      if (start == null) return false;
      return start.isAfter(nowUtc);
    }).length;
    return count;
  }
}
