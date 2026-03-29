import 'package:dio/dio.dart';
import '../../core/api_client.dart';

class NotApprovedException implements Exception {
  final String message;
  NotApprovedException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  /// Đăng nhập
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await api.dio.post(
        '/api/Auth/login',
        data: {'username': username, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final txt = e.response?.data?.toString().toLowerCase() ?? '';
        if (txt.contains('chưa được duyệt')) {
          throw NotApprovedException('Tài khoản chưa được duyệt.');
        }
      }
      throw _err(e, 'Đăng nhập thất bại');
    }
  }

  /// Đăng ký – thêm desiredRole (Resident/Vendor) và inviteCode (nếu Vendor)
  /// Giai đoạn 2: Liên kết căn hộ (chỉ cho Resident)
  Future<String> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
    String desiredRole = 'Resident',   // chỉ Resident hoặc Vendor
    String? inviteCode,                // yêu cầu nếu desiredRole=Vendor
    String? apartmentCode,            // Mã căn hộ (Resident)
    String? nationalId,               // CMND/CCCD (Resident)
    String? residentType,             // "Owner" | "Tenant" (Resident)
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'fullName': fullName,
        'email': email,
        'phoneNumber': phone,
        'desiredRole': desiredRole,
        if (inviteCode != null && inviteCode.isNotEmpty) 'inviteCode': inviteCode,
        // Giai đoạn 2: Liên kết căn hộ
        if (apartmentCode != null && apartmentCode.isNotEmpty) 'apartmentCode': apartmentCode,
        if (nationalId != null && nationalId.isNotEmpty) 'nationalId': nationalId,
        if (residentType != null && residentType.isNotEmpty) 'residentType': residentType,
      };

      final res = await api.dio.post(
        '/api/Auth/register',
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.plain, // server trả text
        ),
      );
      return res.data.toString();
    } on DioException catch (e) {
      throw _err(e, 'Đăng ký thất bại');
    }
  }

  /// Lấy profile
  Future<Map<String, dynamic>> profile() async {
    try {
      final res = await api.dio.get('/api/Auth/profile');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _err(e, 'Không thể tải thông tin người dùng');
    }
  }

  /// Gửi OTP quên mật khẩu qua số điện thoại
  Future<void> forgotPasswordByPhone(String phone) async {
    try {
      await api.dio.post(
        '/api/Auth/forgot-password-phone',
        data: {'phoneNumber': phone},
      );
    } on DioException catch (e) {
      throw _err(e, 'Không thể gửi mã OTP');
    }
  }

  /// Đặt lại mật khẩu với OTP
  Future<void> resetPasswordByPhone({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await api.dio.post(
        '/api/Auth/reset-password-phone',
        data: {
          'phoneNumber': phone,
          'otp': otp,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _err(e, 'Không thể đặt lại mật khẩu');
    }
  }

  /// Gửi OTP quên mật khẩu qua email (Gmail)
  Future<void> forgotPasswordByEmail(String email) async {
    try {
      await api.dio.post(
        '/api/Auth/forgot-password-email',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _err(e, 'Không thể gửi OTP qua email');
    }
  }

  /// Đặt lại mật khẩu bằng email + OTP
  Future<void> resetPasswordByEmail({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await api.dio.post(
        '/api/Auth/reset-password-email',
        data: {
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _err(e, 'Không thể đặt lại mật khẩu (email)');
    }
  }

  String _err(DioException e, String prefix) {
    final status = e.response?.statusCode;
    final url = e.requestOptions.uri.toString();
    final msg = e.response?.data?.toString();

    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.unknown) {
      return '$prefix: Không thể kết nối đến máy chủ.\nURL: $url';
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return '$prefix: Máy chủ phản hồi quá chậm (timeout).\nURL: $url';
    }
    if (e.response != null) return '$prefix: [$status]\nURL: $url\n$msg';
    return '$prefix: ${e.message ?? "Lỗi không xác định"}';
  }
}
