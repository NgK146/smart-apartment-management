import '../../core/api_client.dart';
import 'service_provider_model.dart';

class ServiceProvidersService {
  Future<List<ServiceProviderModel>> list({int page = 1, int pageSize = 50, String? search, String? category}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null) queryParams['search'] = search;
    if (category != null) queryParams['category'] = category;
    final res = await api.dio.get('/api/ServiceProviders', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => ServiceProviderModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ServiceProviderModel> get(String id) async {
    final res = await api.dio.get('/api/ServiceProviders/$id');
    return ServiceProviderModel.fromJson(Map<String, dynamic>.from(res.data));
  }
}


