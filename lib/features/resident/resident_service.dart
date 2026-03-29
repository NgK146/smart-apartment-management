import '../../core/api_client.dart';

class ResidentProfileVm {
  final String id;
  final String? phone;
  final String? email;
  final String apartmentCode;
  final bool isVerifiedByBQL;
  ResidentProfileVm({required this.id, this.phone, this.email, required this.apartmentCode, this.isVerifiedByBQL = false});
  factory ResidentProfileVm.fromJson(Map<String,dynamic> j){
    final apt = j['apartment'] as Map<String,dynamic>?;
    final code = (apt?['code'] ?? '').toString();
    final isVerified = (j['isVerifiedByBQL'] ?? false).toString().toLowerCase() == 'true';
    return ResidentProfileVm(
      id: j['id'].toString(),
      phone: j['phone']?.toString(),
      email: j['email']?.toString(),
      apartmentCode: code,
      isVerifiedByBQL: isVerified,
    );
  }
}

class ResidentService {
  Future<ResidentProfileVm?> myProfile() async {
    final res = await api.dio.get('/api/Residents/me');
    if (res.statusCode == 200) {
      return ResidentProfileVm.fromJson(Map<String,dynamic>.from(res.data));
    }
    return null;
  }

  Future<void> linkApartment({required String apartmentCode, String? nationalId, String? phone, String? email}) async {
    await api.dio.post('/api/Residents/me/link-apartment', data: {
      'apartmentCode': apartmentCode,
      if (nationalId != null && nationalId.isNotEmpty) 'nationalId': nationalId,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    });
  }
}




