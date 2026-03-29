import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/locker_transaction.dart';
import '../models/enums.dart';

class LockerService {
  final String baseUrl;
  final String token;

  LockerService({
    required this.baseUrl,
    required this.token,
  });

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Security: Receive package from shipper
  Future<Map<String, dynamic>> receivePackage({
    required String apartmentCode,
    String? notes,
  }) async {
    final headers = _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/locker/receive'),
      headers: headers,
      body: jsonEncode({
        'apartmentCode': apartmentCode,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to receive package');
    }
  }

  /// Security: Open compartment for dropping package
  Future<void> openDrop(String transactionId) async {
    final headers = _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/locker/$transactionId/open-drop'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to open compartment');
    }
  }

  /// Security: Confirm package has been stored
  Future<String> confirmStored(String transactionId) async {
    final headers = _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/locker/$transactionId/confirm-stored'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['otp'] as String;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to confirm stored');
    }
  }

  /// Resident: Verify OTP before pickup
  Future<void> verifyPickup({
    required String transactionId,
    required String otp,
  }) async {
    final headers = _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/locker/$transactionId/verify-pickup'),
      headers: headers,
      body: jsonEncode({'otp': otp}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'OTP verification failed');
    }
  }

  /// Resident: Confirm package has been picked up
  Future<void> confirmPicked(String transactionId) async {
    final headers = _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/locker/$transactionId/confirm-picked'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to confirm pickup');
    }
  }

  /// Resident: Get my transactions
  Future<List<LockerTransaction>> getMyTransactions({
    LockerTransactionStatus? status,
  }) async {
    final headers = _getHeaders();
    String url = '$baseUrl/api/locker/my-transactions';
    
    if (status != null) {
      url += '?status=${status.name}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List;
      return data.map((json) => LockerTransaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  /// Security: Get security transactions
  Future<List<LockerTransaction>> getSecurityTransactions({
    LockerTransactionStatus? status,
  }) async {
    final headers = _getHeaders();
    String url = '$baseUrl/api/locker/security-transactions';
    
    if (status != null) {
      url += '?status=${status.name}';
    } else {
      // Default to ReceivedBySecurity
      url += '?status=receivedBySecurity';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List;
      return data.map((json) => LockerTransaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load security transactions');
    }
  }
}
