import 'package:dio/dio.dart';
import '../../features/suggestions/models/suggestion_model.dart';

class SuggestionsService {
  final Dio _dio;

  SuggestionsService(this._dio);

  /// Lấy danh sách gợi ý hoạt động cho cư dân hiện tại
  Future<List<Suggestion>> getMySuggestions() async {
    try {
      final response = await _dio.get('/api/Suggestions/my-suggestions');
      final data = response.data['suggestions'] as List;
      return data.map((json) => Suggestion.fromJson(json)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  /// Lấy danh sách gợi ý cho resident cụ thể (admin/manager)
  Future<List<Suggestion>> getSuggestionsForResident(String residentId) async {
    final response = await _dio.get('/api/Suggestions/resident/$residentId');
    final data = response.data['suggestions'] as List;
    return data.map((json) => Suggestion.fromJson(json)).toList();
  }
}

