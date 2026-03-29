import '../../core/api_client.dart';
import 'fee_definition_model.dart';

class FeeDefinitionsService {
  // GET /api/Fees: Lấy danh sách loại phí
  Future<List<FeeDefinitionModel>> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? isActive,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (isActive != null) queryParams['isActive'] = isActive;
    final res = await api.dio.get('/api/Fees', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => FeeDefinitionModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // GET /api/Fees/{id}: Lấy chi tiết loại phí
  Future<FeeDefinitionModel> get(String id) async {
    final res = await api.dio.get('/api/Fees/$id');
    return FeeDefinitionModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  // POST /api/Fees: Tạo loại phí mới
  Future<FeeDefinitionModel> create(FeeDefinitionModel model) async {
    final res = await api.dio.post('/api/Fees', data: model.toJson());
    return FeeDefinitionModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  // PUT /api/Fees/{id}: Cập nhật loại phí
  Future<void> update(String id, FeeDefinitionModel model) async {
    await api.dio.put('/api/Fees/$id', data: model.toJson());
  }

  // DELETE /api/Fees/{id}: Xóa loại phí (soft delete)
  Future<void> delete(String id) async {
    await api.dio.delete('/api/Fees/$id');
  }
}

