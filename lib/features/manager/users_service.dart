import '../../core/api_client.dart';

class UserLite {
  final String id, username;
  final String? fullName, email, phone, requestedRole; // thêm requestedRole
  final bool isApproved;
  UserLite({
    required this.id, required this.username, this.fullName, this.email, this.phone,
    required this.isApproved, this.requestedRole,
  });
  factory UserLite.fromJson(Map<String, dynamic> j) => UserLite(
    id: j['id']?.toString() ?? '',
    username: (j['userName'] ?? j['username'] ?? '').toString(),
    fullName: j['fullName']?.toString(),
    email: j['email']?.toString(),
    phone: j['phoneNumber']?.toString(),
    requestedRole: (j['requestedRole'] ?? j['desiredRole'])?.toString(),
    isApproved: j['isApproved'] == true,
  );
}

class UsersService {
  Future<(List<UserLite> items, int total)> list({int page=1, int pageSize=50, String? search}) async {
    final res = await api.dio.get('/api/Users', queryParameters: {'page': page, 'pageSize': pageSize, if(search!=null) 'search': search});
    final items = (res.data['items'] as List).map((e)=> UserLite.fromJson(Map<String,dynamic>.from(e))).toList();
    final total = res.data['total'] as int? ?? items.length;
    return (items, total);
  }

  Future<void> approve(String username) async {
    await api.dio.post('/api/Users/$username/approve');
  }

  Future<void> assignRole(String username, String role) async {
    await api.dio.post('/api/Users/$username/role/$role');
  }

  Future<Map<String, dynamic>> getDetails(String username) async {
    final res = await api.dio.get('/api/Users/$username/details');
    return Map<String, dynamic>.from(res.data);
  }

  List<String> supportedRoles() => const ['Resident','Manager','Security','Vendor'];
}
