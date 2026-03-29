import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokens {
  static const _kAccess = 'access_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String token) => _storage.write(key: _kAccess, value: token);
  static Future<String?> get() => _storage.read(key: _kAccess);
  static Future<void> clear() => _storage.delete(key: _kAccess);
}
