import '../../core/api_client.dart';
import 'invoice_model.dart';

class InvoicesService {
  // GET /api/invoices/my-invoices: Lấy hóa đơn của cư dân
  Future<List<InvoiceModel>> getMyInvoices({int page = 1, int pageSize = 20, String? status}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/Invoices/my-invoices', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<int> countMyInvoices({String? status}) async {
    final queryParams = <String, dynamic>{'page': 1, 'pageSize': 1};
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/Invoices/my-invoices', queryParameters: queryParams);
    final total = res.data['total'];
    if (total is int) return total;
    final items = res.data['items'] as List?;
    return items?.length ?? 0;
  }

  // GET /api/invoices: Lấy danh sách hóa đơn (cho admin hoặc resident)
  Future<List<InvoiceModel>> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? apartmentId,
    int? month,
    int? year,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (status != null) queryParams['status'] = status;
    if (apartmentId != null) queryParams['apartmentId'] = apartmentId;
    if (month != null) queryParams['month'] = month;
    if (year != null) queryParams['year'] = year;
    final res = await api.dio.get('/api/Invoices', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<InvoiceModel> get(String id) async {
    final res = await api.dio.get('/api/Invoices/$id');
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<Map<String, dynamic>> pay(String invoiceId, double amount, String method, String? transactionRef) async {
    final res = await api.dio.post('/api/Invoices/$invoiceId/pay', data: {
      'amount': amount,
      'method': method,
      'transactionRef': transactionRef ?? 'APP-${DateTime.now().millisecondsSinceEpoch}'
    });
    return Map<String, dynamic>.from(res.data);
  }

  // POST /api/Payments/{invoiceId}/create-payos-link: Tạo link thanh toán PayOS
  Future<Map<String, dynamic>> createPayOsLink(String invoiceId,
      {String? description}) async {
    final res = await api.dio.post(
      '/api/Payments/$invoiceId/create-payos-link',
      data: description != null ? {'description': description} : null,
    );
    final data = Map<String, dynamic>.from(res.data);
    data['checkoutUrl'] ??= data['paymentUrl'];
    data['qrData'] ??= data['qrCode'] ?? data['checkoutUrl'];
    return data;
  }

  // PUT /api/invoices/{id}/confirm-manual-payment: BQL xác nhận thanh toán thủ công
  Future<void> confirmManualPayment(String invoiceId) async {
    await api.dio.put('/api/Invoices/$invoiceId/confirm-manual-payment');
  }

  // DELETE /api/invoices/{id}: Xoá hoá đơn (dùng cho trang quản lý)
  Future<void> delete(String invoiceId) async {
    await api.dio.delete('/api/Invoices/$invoiceId');
  }
}
