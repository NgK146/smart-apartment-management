import 'package:characters/characters.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';

class SmartAiService {
  Future<({String weather, String advice})> askAi({String city = 'Ho Chi Minh'}) async {
    final normalized = _normalizeCity(city);
    final res = await api.dio.get('/api/SmartHome/ask-ai', queryParameters: {'city': normalized});
    final data = res.data as Map<String, dynamic>;
    return (
      weather: data['weather_info']?.toString() ?? '',
      advice: data['ai_advice']?.toString() ?? ''
    );
  }

  Future<({List<Map<String, dynamic>> places, String advice, String weather})> askAiLocation() async {
    // Xin quyền truy cập vị trí
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Quyền truy cập vị trí bị từ chối');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền truy cập vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong cài đặt.');
    }

    // Lấy tọa độ hiện tại
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Gọi endpoint mới với Groq + OSM
    final res = await api.dio.get(
      '/api/SmartHome/advice',
      queryParameters: {
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );
    final data = res.data as Map<String, dynamic>;
    
    // Parse Places từ List
    List<Map<String, dynamic>> placesList = [];
    if (data['places'] != null && data['places'] is List) {
      placesList = (data['places'] as List).map((p) => Map<String, dynamic>.from(p)).toList();
    }
    
    return (
      places: placesList,
      advice: data['aiAdvice']?.toString() ?? '',
      weather: data['weatherInfo']?.toString() ?? ''
    );
  }

  Future<String> controlDevice({String deviceName = 'Đèn Thông Minh', String action = 'BẬT'}) async {
    final res = await api.dio.post(
      '/api/SmartHome/control-device',
      data: {'deviceName': deviceName, 'action': action},
    );
    return res.data['message']?.toString() ?? 'Đã gửi lệnh';
  }

  String _normalizeCity(String input) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIoooooooooooooooooUUUUUUUUUUYYYYYD';
    var output = StringBuffer();
    for (final ch in input.trim().characters) {
      final idx = from.indexOf(ch);
      output.write(idx >= 0 ? to[idx] : ch);
    }
    return output.toString();
  }
}

final smartAiService = SmartAiService();

