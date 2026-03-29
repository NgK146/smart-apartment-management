import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Service để tích hợp với Payment Gateway
/// Sử dụng Client ID, API Key và Checksum Key để xác thực
class PaymentGatewayService {
  // Thông tin xác thực
  static const String clientId = '5ecc19df-bc6a-4fa6-b9c7-f2731a212437';
  static const String apiKey = '857525cb-f356-47d4-8d34-6ac48aa1d621';
  static const String checksumKey = '37531a5f183f60d948abee2645e11e38efa1f9496818559e79009a403b97ff54';

  final Dio _dio;

  PaymentGatewayService(this._dio);

  /// Tạo checksum từ dữ liệu và checksum key
  /// Sử dụng HMAC-SHA256
  String _generateChecksum(Map<String, dynamic> data) {
    // Sắp xếp các key theo thứ tự alphabet và tạo chuỗi query string
    final sortedKeys = data.keys.toList()..sort();
    final queryString = sortedKeys
        .map((key) => '$key=${data[key]}')
        .join('&');

    // Tạo HMAC-SHA256
    final key = utf8.encode(checksumKey);
    final bytes = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return digest.toString();
  }

  /// Tạo request với xác thực đầy đủ
  Map<String, dynamic> _createAuthenticatedRequest(Map<String, dynamic> payload) {
    // Thêm clientId vào payload
    final requestData = {
      ...payload,
      'clientId': clientId,
    };

    // Tạo checksum
    final checksum = _generateChecksum(requestData);

    // Thêm checksum vào request
    requestData['checksum'] = checksum;

    return requestData;
  }

  /// Tạo yêu cầu thanh toán
  /// 
  /// [amount] - Số tiền cần thanh toán (VND)
  /// [orderId] - Mã đơn hàng/hóa đơn
  /// [orderDescription] - Mô tả đơn hàng
  /// [returnUrl] - URL để redirect sau khi thanh toán thành công
  /// [cancelUrl] - URL để redirect nếu hủy thanh toán
  Future<Map<String, dynamic>> createPaymentRequest({
    required double amount,
    required String orderId,
    String? orderDescription,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    final payload = {
      'amount': amount.toInt(),
      'orderId': orderId,
      'orderDescription': orderDescription ?? 'Thanh toán đơn hàng $orderId',
      'currency': 'VND',
      'returnUrl': returnUrl ?? '',
      'cancelUrl': cancelUrl ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final requestData = _createAuthenticatedRequest(payload);

    try {
      // Gửi request đến API thanh toán
      // Lưu ý: Thay đổi URL này theo API endpoint thực tế của payment gateway
      final response = await _dio.post(
        '/api/PaymentGateway/create-payment',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'X-Client-Id': clientId,
          },
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Lỗi khi tạo yêu cầu thanh toán: ${e.toString()}');
    }
  }

  /// Kiểm tra trạng thái thanh toán
  /// 
  /// [transactionId] - Mã giao dịch từ payment gateway
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    final payload = {
      'transactionId': transactionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final requestData = _createAuthenticatedRequest(payload);

    try {
      final response = await _dio.post(
        '/api/PaymentGateway/check-status',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'X-Client-Id': clientId,
          },
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Lỗi khi kiểm tra trạng thái thanh toán: ${e.toString()}');
    }
  }

  /// Xác thực callback từ payment gateway
  /// 
  /// [callbackData] - Dữ liệu callback từ payment gateway
  bool verifyCallback(Map<String, dynamic> callbackData) {
    try {
      // Lấy checksum từ callback
      final receivedChecksum = callbackData['checksum'] as String?;
      if (receivedChecksum == null) {
        return false;
      }

      // Tạo lại checksum từ dữ liệu callback (không bao gồm checksum)
      final dataWithoutChecksum = Map<String, dynamic>.from(callbackData);
      dataWithoutChecksum.remove('checksum');

      final calculatedChecksum = _generateChecksum(dataWithoutChecksum);

      // So sánh checksum
      return receivedChecksum.toLowerCase() == calculatedChecksum.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  /// Hoàn tiền (refund)
  /// 
  /// [transactionId] - Mã giao dịch gốc
  /// [amount] - Số tiền hoàn (nếu null thì hoàn toàn bộ)
  /// [reason] - Lý do hoàn tiền
  Future<Map<String, dynamic>> refund({
    required String transactionId,
    double? amount,
    String? reason,
  }) async {
    final payload = {
      'transactionId': transactionId,
      'amount': amount?.toInt(),
      'reason': reason ?? 'Hoàn tiền theo yêu cầu',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    // Loại bỏ các giá trị null
    payload.removeWhere((key, value) => value == null);

    final requestData = _createAuthenticatedRequest(payload);

    try {
      final response = await _dio.post(
        '/api/PaymentGateway/refund',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'X-Client-Id': clientId,
          },
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Lỗi khi thực hiện hoàn tiền: ${e.toString()}');
    }
  }

  /// Tạo QR code thanh toán
  /// 
  /// [amount] - Số tiền
  /// [orderId] - Mã đơn hàng
  /// [orderDescription] - Mô tả
  Future<Map<String, dynamic>> createQRCode({
    required double amount,
    required String orderId,
    String? orderDescription,
  }) async {
    final paymentRequest = await createPaymentRequest(
      amount: amount,
      orderId: orderId,
      orderDescription: orderDescription,
    );

    // Nếu payment gateway trả về QR code trực tiếp
    if (paymentRequest.containsKey('qrCode') || paymentRequest.containsKey('qrData')) {
      return paymentRequest;
    }

    // Nếu cần tạo QR code từ payment URL
    if (paymentRequest.containsKey('paymentUrl')) {
      return {
        ...paymentRequest,
        'qrCode': paymentRequest['paymentUrl'],
        'qrData': paymentRequest['paymentUrl'],
      };
    }

    throw Exception('Không thể tạo QR code từ response');
  }
}

