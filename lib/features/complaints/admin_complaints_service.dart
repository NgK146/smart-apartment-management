import '../../core/api_client.dart';
import 'complaint_model.dart';

// Service cho admin quản lý phản ánh
class AdminComplaintsService {
  // Lấy danh sách phản ánh (Admin)
  Future<(List<ComplaintModel> items, int total)> list({
    int page = 1,
    int pageSize = 50,
    String? trangThai,
    String? loaiPhanAnh,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
      if (trangThai != null && trangThai.isNotEmpty) queryParams['trangThai'] = trangThai;
      if (loaiPhanAnh != null && loaiPhanAnh.isNotEmpty) queryParams['loaiPhanAnh'] = loaiPhanAnh;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final res = await api.dio.get('/api/admin/Complaints', queryParameters: queryParams);
      
      if (res.data == null) {
        print('Admin complaints response is null');
        return (<ComplaintModel>[], 0);
      }

      if (res.data['items'] == null) {
        print('Admin complaints items is null');
        return (<ComplaintModel>[], res.data['total'] as int? ?? 0);
      }

      final itemsList = res.data['items'] as List? ?? [];
      print('Admin complaints items count: ${itemsList.length}');
      
      final items = itemsList.map((e) {
        try {
          return ComplaintModel.fromJson(Map<String, dynamic>.from(e));
        } catch (e) {
          print('Error parsing complaint item: $e');
          return null;
        }
      }).whereType<ComplaintModel>().toList();
      
      final total = res.data['total'] as int? ?? items.length;
      print('Admin complaints parsed: ${items.length} items, total: $total');
      
      return (items, total);
    } catch (e) {
      print('Error loading admin complaints: $e');
      rethrow;
    }
  }

  // Xem chi tiết phản ánh (Admin)
  Future<ComplaintModel> getDetails(String id) async {
    try {
      final res = await api.dio.get('/api/admin/Complaints/$id');
      if (res.data == null) {
        throw Exception('Không có dữ liệu');
      }
      return ComplaintModel.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      print('Error loading complaint details: $e');
      rethrow;
    }
  }

  // Cập nhật phản ánh (Admin)
  Future<void> update({
    required String id,
    String? trangThai,
    String? phanHoiAdmin,
  }) async {
    try {
      await api.dio.put('/api/admin/Complaints/$id', data: {
        if (trangThai != null && trangThai.isNotEmpty) 'trangThai': trangThai,
        if (phanHoiAdmin != null) 'phanHoiAdmin': phanHoiAdmin,
      });
    } catch (e) {
      print('Error updating complaint: $e');
      rethrow;
    }
  }

  // Xóa phản ánh (Admin)
  Future<void> delete(String id) async {
    try {
      await api.dio.delete('/api/admin/Complaints/$id');
    } catch (e) {
      print('Error deleting complaint: $e');
      rethrow;
    }
  }

  // Lấy thống kê
  Future<Map<String, int>> getStats() async {
    try {
      final res = await api.dio.get('/api/admin/Complaints/stats');
      return {
        'tongSo': res.data['tongSo'] ?? 0,
        'chuaXuLy': res.data['chuaXuLy'] ?? 0,
        'daPhanHoi': res.data['daPhanHoi'] ?? 0,
        'daDong': res.data['daDong'] ?? 0,
      };
    } catch (e) {
      print('Error loading stats: $e');
      return {
        'tongSo': 0,
        'chuaXuLy': 0,
        'daPhanHoi': 0,
        'daDong': 0,
      };
    }
  }
}
