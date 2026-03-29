import 'package:dio/dio.dart';
import '../config/config_url.dart';
import 'storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  ApiClient() {
    final origin = AppConfig.apiBaseUrl; // ví dụ: https://firstorangepage2.conveyor.cloud
    // Log để chắc chắn base đang dùng là gì
    // ignore: avoid_print
    print('==> BASE ORIGIN: $origin');

    dio = Dio(BaseOptions(
      baseUrl: origin, // chỉ origin, không có /api
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await SecureTokens.get();
        if (t != null && t.isNotEmpty) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        if (e.response?.statusCode == 401) await SecureTokens.clear();
        h.next(e);
      },
    ));

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[DIO] $obj'),
    ));
  }
}
final api = ApiClient();
