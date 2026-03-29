import 'package:dio/dio.dart';
import '../../features/smart_devices/models/smart_device.dart';

class SmartDevicesService {
  final Dio _dio;

  SmartDevicesService(this._dio);

  /// Lấy danh sách barriers
  Future<List<SmartBarrier>> getBarriers() async {
    final response = await _dio.get('/api/SmartDevices/barriers');
    return (response.data as List)
        .map((json) => SmartBarrier.fromJson(json))
        .toList();
  }

  /// Mở barrier bằng QR code
  Future<void> openBarrier(String qrCode) async {
    await _dio.post(
      '/api/SmartDevices/barriers/open',
      data: {'qrCode': qrCode},
    );
  }

  /// Lấy danh sách lockers
  Future<List<SmartLocker>> getLockers() async {
    final response = await _dio.get('/api/SmartDevices/lockers');
    return (response.data as List)
        .map((json) => SmartLocker.fromJson(json))
        .toList();
  }

  /// Đặt locker
  Future<SmartLocker> bookLocker({
    required String lockerId,
    required String packageId,
  }) async {
    final response = await _dio.post(
      '/api/SmartDevices/lockers/$lockerId/book',
      data: {'packageId': packageId},
    );
    return SmartLocker.fromJson(response.data);
  }

  /// Mở locker bằng OTP hoặc QR
  Future<void> openLocker({
    required String lockerId,
    String? otpCode,
    String? qrCode,
  }) async {
    await _dio.post(
      '/api/SmartDevices/lockers/$lockerId/open',
      data: {
        if (otpCode != null) 'otpCode': otpCode,
        if (qrCode != null) 'qrCode': qrCode,
      },
    );
  }

  /// Lấy danh sách EV charging stations
  Future<List<EVChargingStation>> getEVStations() async {
    final response = await _dio.get('/api/SmartDevices/ev-stations');
    return (response.data as List)
        .map((json) => EVChargingStation.fromJson(json))
        .toList();
  }

  /// Đặt slot sạc EV
  Future<EVChargingStation> bookEVStation({
    required String stationId,
    required DateTime startTime,
    int? durationMinutes,
  }) async {
    final response = await _dio.post(
      '/api/SmartDevices/ev-stations/$stationId/book',
      data: {
        'startTime': startTime.toIso8601String(),
        'durationMinutes': durationMinutes,
      },
    );
    return EVChargingStation.fromJson(response.data);
  }

  /// Kết thúc sạc
  Future<EVChargingStation> stopCharging(String stationId) async {
    final response = await _dio.post(
      '/api/SmartDevices/ev-stations/$stationId/stop',
    );
    return EVChargingStation.fromJson(response.data);
  }
}

