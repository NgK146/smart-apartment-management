import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Service để quản lý xác thực vân tay/sinh trắc học
class BiometricService {
  static const _storage = FlutterSecureStorage();
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyBiometricCredentials = 'biometric_credentials'; // Lưu username đã liên kết

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Kiểm tra thiết bị có hỗ trợ vân tay/sinh trắc học không
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra có vân tay/sinh trắc học nào đã được đăng ký không
  Future<bool> hasBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Lấy danh sách các phương thức sinh trắc học có sẵn
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Kiểm tra vân tay đã được liên kết với username chưa
  Future<bool> isBiometricEnabledForUser(String username) async {
    try {
      final enabled = await _storage.read(key: _keyBiometricEnabled);
      if (enabled != 'true') return false;

      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      if (credentialsJson == null) return false;

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      return credentials.containsKey(username);
    } catch (e) {
      return false;
    }
  }

  /// Liên kết vân tay với username và password (sau khi xác thực thành công)
  Future<bool> enableBiometricForUser(String username, String password) async {
    try {
      // Xác thực vân tay trước
      final authenticated = await authenticate(
        reason: 'Xác thực để liên kết vân tay với tài khoản',
      );

      if (!authenticated) {
        debugPrint('BiometricService: Xác thực vân tay thất bại hoặc bị hủy');
        return false;
      }

      debugPrint('BiometricService: Xác thực vân tay thành công, đang lưu thông tin...');

      // Lưu thông tin
      await _storage.write(key: _keyBiometricEnabled, value: 'true');

      // Lấy danh sách credentials hiện tại
      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      Map<String, dynamic> credentials = {};
      if (credentialsJson != null) {
        credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      }

      // Thêm username và password (đã mã hóa cơ bản)
      // Lưu ý: Password được lưu trong secure storage, nhưng vẫn nên mã hóa thêm
      credentials[username] = {
        'password': password, // Lưu password để đăng nhập tự động
        'enabledAt': DateTime.now().toIso8601String(),
      };

      await _storage.write(
        key: _keyBiometricCredentials,
        value: jsonEncode(credentials),
      );

      debugPrint('BiometricService: Đã lưu thông tin vân tay cho user: $username');
      
      // Verify lại xem đã lưu thành công chưa
      final verifyJson = await _storage.read(key: _keyBiometricCredentials);
      if (verifyJson != null) {
        final verifyCredentials = jsonDecode(verifyJson) as Map<String, dynamic>;
        if (verifyCredentials.containsKey(username)) {
          debugPrint('BiometricService: Xác nhận đã lưu thành công');
          return true;
        }
      }

      debugPrint('BiometricService: Lỗi: Không thể xác nhận đã lưu');
      return false;
    } catch (e) {
      debugPrint('BiometricService: Lỗi khi liên kết vân tay: $e');
      return false;
    }
  }

  /// Hủy liên kết vân tay với username (xóa cả password)
  Future<bool> disableBiometricForUser(String username) async {
    try {
      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      if (credentialsJson == null) return true;

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      credentials.remove(username);

      if (credentials.isEmpty) {
        // Nếu không còn user nào, tắt hoàn toàn
        await _storage.delete(key: _keyBiometricEnabled);
        await _storage.delete(key: _keyBiometricCredentials);
      } else {
        await _storage.write(
          key: _keyBiometricCredentials,
          value: jsonEncode(credentials),
        );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cập nhật password cho username đã liên kết (khi user đổi password)
  Future<bool> updatePasswordForUser(String username, String newPassword) async {
    try {
      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      if (credentialsJson == null) return false;

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      if (!credentials.containsKey(username)) return false;

      final userData = credentials[username] as Map<String, dynamic>;
      userData['password'] = newPassword;

      await _storage.write(
        key: _keyBiometricCredentials,
        value: jsonEncode(credentials),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Lấy danh sách username đã liên kết vân tay
  Future<List<String>> getLinkedUsernames() async {
    try {
      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      if (credentialsJson == null) return [];

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      return credentials.keys.toList();
    } catch (e) {
      return [];
    }
  }

  /// Xác thực vân tay/sinh trắc học
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      debugPrint('BiometricService: Bắt đầu xác thực vân tay...');
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Chỉ dùng vân tay, không dùng PIN/Password
        ),
      );
      debugPrint('BiometricService: Kết quả xác thực vân tay: $result');
      return result;
    } catch (e) {
      debugPrint('BiometricService: Lỗi khi xác thực vân tay: $e');
      return false;
    }
  }

  /// Lấy password đã lưu cho username (sau khi xác thực vân tay)
  Future<String?> getPasswordForUser(String username) async {
    try {
      final credentialsJson = await _storage.read(key: _keyBiometricCredentials);
      if (credentialsJson == null) return null;

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      final userData = credentials[username] as Map<String, dynamic>?;
      return userData?['password'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Xác thực vân tay để đăng nhập (lấy username và password từ storage)
  Future<Map<String, String>?> authenticateForLogin() async {
    try {
      // Kiểm tra có vân tay nào đã được liên kết không
      final usernames = await getLinkedUsernames();
      if (usernames.isEmpty) return null;

      // Xác thực vân tay
      final authenticated = await authenticate(
        reason: 'Xác thực vân tay để đăng nhập',
      );

      if (!authenticated) return null;

      // Lấy username (nếu có nhiều, lấy user đầu tiên)
      final username = usernames.first;
      
      // Lấy password đã lưu
      final password = await getPasswordForUser(username);
      if (password == null || password.isEmpty) {
        return null;
      }

      return {
        'username': username,
        'password': password,
      };
    } catch (e) {
      return null;
    }
  }

  /// Kiểm tra vân tay có được bật cho bất kỳ user nào không
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _keyBiometricEnabled);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }
}

