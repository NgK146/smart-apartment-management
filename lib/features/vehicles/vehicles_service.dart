import '../../core/api_client.dart';
import 'vehicle_model.dart';
import 'parking_plan_model.dart';
import 'parking_pass_model.dart';

class VehiclesService {
  // ========== Vehicle Methods ==========
  Future<List<VehicleModel>> list({int page = 1, int pageSize = 20, String? search, String? residentProfileId, String? status}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (search != null) queryParams['search'] = search;
    if (residentProfileId != null) queryParams['residentProfileId'] = residentProfileId;
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/Vehicles', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => VehicleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<VehicleModel> get(String id) async {
    final res = await api.dio.get('/api/Vehicles/$id');
    return VehicleModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<VehicleModel> create(VehicleModel vehicle) async {
    final res = await api.dio.post('/api/Vehicles', data: vehicle.toJson());
    return VehicleModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> update(String id, VehicleModel vehicle) async {
    await api.dio.put('/api/Vehicles/$id', data: vehicle.toJson());
  }

  Future<void> delete(String id) async {
    await api.dio.delete('/api/Vehicles/$id');
  }

  // Admin: Duyệt xe
  Future<void> approveVehicle(String id) async {
    await api.dio.post('/api/Vehicles/$id/approve');
  }

  // Admin: Từ chối xe
  Future<void> rejectVehicle(String id, String reason) async {
    await api.dio.post('/api/Vehicles/$id/reject', data: {'reason': reason});
  }

  // ========== ParkingPlan Methods ==========
  Future<List<ParkingPlanModel>> listPlans({int page = 1, int pageSize = 20, String? vehicleType, bool? isActive}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (vehicleType != null) queryParams['vehicleType'] = vehicleType;
    if (isActive != null) queryParams['isActive'] = isActive;
    final res = await api.dio.get('/api/ParkingPlans', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => ParkingPlanModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ParkingPlanModel> getPlan(String id) async {
    final res = await api.dio.get('/api/ParkingPlans/$id');
    return ParkingPlanModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<ParkingPlanModel> createPlan(ParkingPlanModel plan) async {
    final res = await api.dio.post('/api/ParkingPlans', data: plan.toJson());
    return ParkingPlanModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> updatePlan(String id, ParkingPlanModel plan) async {
    await api.dio.put('/api/ParkingPlans/$id', data: plan.toJson());
  }

  Future<void> deletePlan(String id) async {
    await api.dio.delete('/api/ParkingPlans/$id');
  }

  // ========== ParkingPass Methods ==========
  Future<List<ParkingPassModel>> listPasses({int page = 1, int pageSize = 20, String? vehicleId, String? status}) async {
    final queryParams = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (vehicleId != null) queryParams['vehicleId'] = vehicleId;
    if (status != null) queryParams['status'] = status;
    final res = await api.dio.get('/api/ParkingPasses', queryParameters: queryParams);
    return (res.data['items'] as List).map((e) => ParkingPassModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ParkingPassModel> getPass(String id) async {
    final res = await api.dio.get('/api/ParkingPasses/$id');
    return ParkingPassModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  // Cư dân: Đăng ký mua vé
  Future<ParkingPassModel> registerPass({
    required String vehicleId,
    required String parkingPlanId,
    required DateTime validFrom,
  }) async {
    final res = await api.dio.post('/api/ParkingPasses/register', data: {
      'vehicleId': vehicleId,
      'parkingPlanId': parkingPlanId,
      'validFrom': validFrom.toIso8601String(),
    });
    return ParkingPassModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  // Admin: Hủy vé
  Future<void> revokePass(String id, String reason) async {
    await api.dio.post('/api/ParkingPasses/$id/revoke', data: {'reason': reason});
  }
}


