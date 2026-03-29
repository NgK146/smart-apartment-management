import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    String base = (fromDefine.isNotEmpty
        ? fromDefine
        : (dotenv.env['API_BASE_URL'] ?? '')).trim();
    if (base.isEmpty) base = 'http://10.0.2.2:5000'; // fallback dev
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  static String resolve(String path) {
    if (path.isEmpty) return apiBaseUrl;
    if (path.startsWith('http')) return path;
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${apiBaseUrl}/$normalized';
  }
}