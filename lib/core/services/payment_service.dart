import 'package:dio/dio.dart';
import '../../features/payment/models/digital_payment.dart';
import 'payment_gateway_service.dart';

class PaymentService {
  final Dio _dio;
  late final PaymentGatewayService _gatewayService;

  PaymentService(this._dio) {
    _gatewayService = PaymentGatewayService(_dio);
  }

  /// Lấy thông tin ví điện tử
  Future<DigitalWallet> getWallet() async {
    final response = await _dio.get('/api/Payment/wallet');
    return DigitalWallet.fromJson(response.data);
  }

  /// Nạp tiền vào ví
  Future<WalletTransaction> topUp({
    required double amount,
    required String paymentMethodId,
  }) async {
    final response = await _dio.post(
      '/api/Payment/top-up',
      data: {
        'amount': amount,
        'paymentMethodId': paymentMethodId,
      },
    );
    return WalletTransaction.fromJson(response.data);
  }

  /// Thanh toán hóa đơn
  Future<WalletTransaction> payInvoice({
    required String invoiceId,
    required String paymentMethodId,
  }) async {
    final response = await _dio.post(
      '/api/Payment/pay-invoice',
      data: {
        'invoiceId': invoiceId,
        'paymentMethodId': paymentMethodId,
      },
    );
    return WalletTransaction.fromJson(response.data);
  }

  /// Lấy lịch sử giao dịch
  Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/api/Payment/transactions',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (response.data['items'] as List)
        .map((json) => WalletTransaction.fromJson(json))
        .toList();
  }

  /// Lấy danh sách phương thức thanh toán
  Future<List<PaymentMethod>> getPaymentMethods() async {
    final response = await _dio.get('/api/Payment/methods');
    return (response.data as List)
        .map((json) => PaymentMethod.fromJson(json))
        .toList();
  }

  /// Lấy danh sách nhắc nhở thanh toán
  Future<List<PaymentReminder>> getPaymentReminders() async {
    final response = await _dio.get('/api/Payment/reminders');
    return (response.data as List)
        .map((json) => PaymentReminder.fromJson(json))
        .toList();
  }

  /// Tạo link thanh toán PayOS cho hóa đơn (thay thế VNPay cũ)
  Future<Map<String, dynamic>> createPayOsLinkForInvoice(String invoiceId,
      {String? description}) async {
    final response = await _dio.post(
      '/api/Payments/$invoiceId/create-payos-link',
      data: description != null ? {'description': description} : null,
    );
    final data = Map<String, dynamic>.from(response.data);
    // Đảm bảo luôn có trường qrData để UI hiện QR hoặc dùng checkoutUrl.
    data['checkoutUrl'] ??= data['paymentUrl'];
    data['qrData'] ??= data['qrCode'] ?? data['checkoutUrl'];
    return data;
  }

  /// Phương thức cũ, giữ để tương thích ngược.
  Future<Map<String, dynamic>> createVnPayLinkForInvoice(String invoiceId) =>
      createPayOsLinkForInvoice(invoiceId);

  /// Lấy trạng thái thanh toán
  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    final response = await _dio.get('/api/Payments/$paymentId/status');
    return Map<String, dynamic>.from(response.data);
  }

  /// Tạo yêu cầu thanh toán qua Payment Gateway
  /// 
  /// [amount] - Số tiền cần thanh toán (VND)
  /// [orderId] - Mã đơn hàng/hóa đơn
  /// [orderDescription] - Mô tả đơn hàng
  /// [returnUrl] - URL để redirect sau khi thanh toán thành công
  /// [cancelUrl] - URL để redirect nếu hủy thanh toán
  Future<Map<String, dynamic>> createGatewayPayment({
    required double amount,
    required String orderId,
    String? orderDescription,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    return await _gatewayService.createPaymentRequest(
      amount: amount,
      orderId: orderId,
      orderDescription: orderDescription,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
    );
  }

  /// Tạo QR code thanh toán qua Payment Gateway
  Future<Map<String, dynamic>> createGatewayQRCode({
    required double amount,
    required String orderId,
    String? orderDescription,
  }) async {
    return await _gatewayService.createQRCode(
      amount: amount,
      orderId: orderId,
      orderDescription: orderDescription,
    );
  }

  /// Kiểm tra trạng thái thanh toán từ Payment Gateway
  Future<Map<String, dynamic>> checkGatewayPaymentStatus(String transactionId) async {
    return await _gatewayService.checkPaymentStatus(transactionId);
  }

  /// Xác thực callback từ Payment Gateway
  bool verifyGatewayCallback(Map<String, dynamic> callbackData) {
    return _gatewayService.verifyCallback(callbackData);
  }

  /// Hoàn tiền qua Payment Gateway
  Future<Map<String, dynamic>> refundGatewayPayment({
    required String transactionId,
    double? amount,
    String? reason,
  }) async {
    return await _gatewayService.refund(
      transactionId: transactionId,
      amount: amount,
      reason: reason,
    );
  }
}

