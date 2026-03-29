import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../vehicles/vehicles_service.dart';
import '../vehicles/vehicle_model.dart';

extension VehicleExtensions on VehicleModel {
  String get statusText {
    switch (status) {
      case 'Pending': return 'Chờ duyệt';
      case 'Approved': return 'Đã duyệt';
      case 'Rejected': return 'Từ chối';
      default: return status;
    }
  }
  String? get rejectionReason => vehicleType.contains('Rejected') ? 'Thiếu giấy tờ xe' : null;
}

class VehiclesAdminPage extends StatefulWidget {
  const VehiclesAdminPage({super.key});

  @override
  State<VehiclesAdminPage> createState() => _VehiclesAdminPageState();
}

class _VehiclesAdminPageState extends State<VehiclesAdminPage> with SingleTickerProviderStateMixin {
  final _svc = VehiclesService();
  final _searchController = TextEditingController();
  List<VehicleModel> _allVehicles = [];
  List<VehicleModel> _filteredVehicles = [];
  bool _loading = true;
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _filterVehicles();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _allVehicles = await _svc.list(pageSize: 200);
      _filterVehicles();
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải danh sách xe: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterVehicles() {
    final search = _searchController.text.toLowerCase().trim();
    final statusFilter = _tabController.index == 0
        ? 'Pending'
        : _tabController.index == 1
        ? 'Approved'
        : null;

    setState(() {
      _filteredVehicles = _allVehicles.where((v) {
        final matchesSearch = search.isEmpty ||
            v.licensePlate.toLowerCase().contains(search) ||
            v.vehicleType.toLowerCase().contains(search);
        final matchesStatus = statusFilter == null || v.status == statusFilter ||
            (statusFilter == 'Approved' && v.status == 'Rejected'); 
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _approveVehicle(VehicleModel vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận duyệt', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn duyệt xe ${vehicle.licensePlate}?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _primaryColor),
            child: Text('Duyệt', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _svc.approveVehicle(vehicle.id);
        if (mounted) {
          showSnack(context, 'Đã duyệt xe thành công');
          _load();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi duyệt xe: $e', error: true);
      }
    }
  }

  Future<void> _rejectVehicle(VehicleModel vehicle) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Từ chối xe', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xe: ${vehicle.licensePlate}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Lý do từ chối *',
                labelStyle: GoogleFonts.inter(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                showSnack(context, 'Vui lòng nhập lý do từ chối', error: true);
                return;
              }
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Từ chối', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _svc.rejectVehicle(vehicle.id, reasonController.text.trim());
        if (mounted) {
          showSnack(context, 'Đã từ chối xe');
          _load();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi từ chối xe: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Duyệt Đăng Ký Xe', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          
          Material(
            color: Colors.white,
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              labelColor: _primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primaryColor,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(),
              onTap: (_) => _filterVehicles(),
              tabs: [
                Tab(text: 'Chờ duyệt (${_allVehicles.where((v) => v.status == 'Pending').length})'),
                Tab(text: 'Đã duyệt'),
                Tab(text: 'Tất cả'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredVehicles.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Không có xe nào', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
                : RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    itemCount: _filteredVehicles.length,
                    itemBuilder: (context, index) {
                      return _buildVehicleCard(_filteredVehicles[index]);
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý phương tiện → Đăng ký xe', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Tổng số: ${_allVehicles.length} xe', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo biển số, loại xe...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterVehicles();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: GoogleFonts.inter(color: Colors.black87),
              onChanged: (_) => _filterVehicles(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    Color statusColor;
    IconData statusIcon;

    if (vehicle.status == 'Approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (vehicle.status == 'Rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    vehicle.vehicleType.contains('Ô tô') ? Icons.directions_car_filled_rounded : Icons.two_wheeler_rounded,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.licensePlate,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle.vehicleType} • ${vehicle.color ?? 'N/A'}',
                        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                      ),
                      if (vehicle.brand != null || vehicle.model != null)
                        Text(
                          '${vehicle.brand ?? ''} ${vehicle.model ?? ''}'.trim(),
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.statusText,
                        style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (vehicle.rejectionReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lý do: ${vehicle.rejectionReason}',
                        style: GoogleFonts.inter(color: Colors.red[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (vehicle.status == 'Pending') ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectVehicle(vehicle),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text('Từ chối', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approveVehicle(vehicle),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('Duyệt', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}