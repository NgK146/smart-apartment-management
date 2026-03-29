import '../../core/api_client.dart';
import 'meter_reading_model.dart';

class BillingService {
  // POST /api/billing/meter-readings: Nhập chỉ số đồng hồ
  Future<List<MeterReadingModel>> createMeterReadings({
    required int month,
    required int year,
    required List<Map<String, dynamic>> readings, // [{apartmentId, feeDefinitionId, reading}]
  }) async {
    final res = await api.dio.post('/api/Billing/meter-readings', data: {
      'month': month,
      'year': year,
      'readings': readings,
    });
    return (res.data as List).map((e) => MeterReadingModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // POST /api/billing/generate-invoices: Tạo hóa đơn hàng loạt
  Future<Map<String, dynamic>> generateInvoices({
    required int month,
    required int year,
    required DateTime dueDate,
  }) async {
    final res = await api.dio.post('/api/Billing/generate-invoices', data: {
      'month': month,
      'year': year,
      'dueDate': dueDate.toIso8601String(),
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> generateManagementFees({
    required int month,
    required int year,
  }) async {
    final res = await api.dio.post('/api/Billing/generate-management-fees', data: {
      'month': month,
      'year': year,
    });
    return Map<String, dynamic>.from(res.data);
  }
}

