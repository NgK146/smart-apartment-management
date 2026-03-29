import 'package:flutter/foundation.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/services/biometric_service.dart';
import 'auth_service.dart';

class AuthState extends ChangeNotifier {
  String? token, username, fullName, userId;
  List<String> roles = [];
  bool isApproved = false;
  String? apartmentCode;
  bool isResidentVerified = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isManagerLike => roles.contains('Manager') || roles.contains('Security');
  bool get isResident => roles.contains('Resident');

  Future<void> login(String u, String p) async {
    final data = await AuthService().login(u, p); // có thể ném NotApprovedException
    // ASP.NET Core tự động serialize sang camelCase, nên AccessToken -> accessToken
    token = data['accessToken'] ?? data['AccessToken']; // hỗ trợ cả hai trường hợp
    username = data['username'] ?? data['Username'];
    fullName = data['fullName'] ?? data['FullName'];
    final dynamic rawRoles = data['roles'] ?? data['Roles'];
    if (rawRoles is List) {
      roles = rawRoles.map((e) => e.toString()).toList();
    } else {
      roles = [];
    }
    await SecureTokens.save(token!);
    await loadProfile(); // lấy isApproved từ claim
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final res = await AuthService().profile();
    // Hỗ trợ cả camelCase và PascalCase
    username = res['username'] ?? res['Username']?.toString();
    fullName = res['fullName'] ?? res['FullName']?.toString();
    userId = res['userId'] ?? res['UserId'] ?? res['id'] ?? res['Id']?.toString();
    final dynamic rolesList = res['roles'] ?? res['Roles'];
    if (rolesList is List) {
      roles = rolesList.map((e) => e.toString()).toList();
    } else {
      roles = [];
    }
    final isApprovedVal = res['isApproved'] ?? res['IsApproved'];
    isApproved = (isApprovedVal?.toString().toLowerCase() == 'true');
    apartmentCode = (res['apartmentCode'] ?? res['ApartmentCode'])?.toString();
    final residentVerifiedVal = res['isResidentVerified'] ?? res['IsResidentVerified'];
    isResidentVerified = residentVerifiedVal?.toString().toLowerCase() == 'true';
    notifyListeners();
  }

  Future<void> logout() async {
    token=null; username=null; fullName=null; userId=null; roles=[]; isApproved=false; apartmentCode=null; isResidentVerified=false;
    await SecureTokens.clear();
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final saved = await SecureTokens.get();
    if (saved != null && saved.isNotEmpty) {
      token = saved;
      try { await loadProfile(); } catch (_) { await logout(); }
    }
  }

  /// Đăng nhập bằng vân tay (cần lấy password từ secure storage hoặc yêu cầu nhập lại)
  /// Lưu ý: Vì không thể lưu password, nên cần user nhập password lần đầu để lưu vào secure storage
  Future<bool> loginWithBiometric(String username, String password) async {
    try {
      await login(username, password);
      return true;
    } catch (e) {
      return false;
    }
  }
}
