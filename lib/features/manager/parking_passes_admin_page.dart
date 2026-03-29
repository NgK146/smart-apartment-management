import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import '../vehicles/vehicles_service.dart';
import '../vehicles/parking_pass_model.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

extension ParkingPassExtension on ParkingPassModel {
  String get statusText {
    switch (status) {
      case 'Active': return 'Đang hoạt động';
      case 'PendingPayment': return 'Chờ TT';
      case 'Expired': return 'Đã hết hạn';
      case 'Revoked': return 'Đã hủy';
      default: return status;
    }
  }

  bool get isActive => status == 'Active';
  bool get needsRenewal => status == 'Active' && daysRemaining <= 7;
  String? get revocationReason => status == 'Revoked' ? "Vi phạm quy định" : null;
  int get daysRemaining {
    if (status != 'Active') return 0;
    return max(0, validTo.difference(DateTime.now()).inDays);
  }
}

class ParkingPassesAdminPage extends StatefulWidget {
  const ParkingPassesAdminPage({super.key});

  @override
  State<ParkingPassesAdminPage> createState() => _ParkingPassesAdminPageState();
}

class _ParkingPassesAdminPageState extends State<ParkingPassesAdminPage> with SingleTickerProviderStateMixin {
  final _svc = VehiclesService();
  final _searchController = TextEditingController();
  List<ParkingPassModel> _allPasses = [];
  List<ParkingPassModel> _filteredPasses = [];
  bool _loading = true;
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
    _searchController.addListener(_filterPasses);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _filterPasses();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _allPasses = await _svc.listPasses(pageSize: 200);
      _filterPasses();
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải danh sách vé: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterPasses() {
    final search = _searchController.text.toLowerCase().trim();
    String? statusFilter;
    switch (_tabController.index) {
      case 0: statusFilter = 'Active'; break;
      case 1: statusFilter = 'PendingPayment'; break;
      case 2: statusFilter = 'Expired'; break;
      case 3: statusFilter = null; break;
    }

    setState(() {
      _filteredPasses = _allPasses.where((p) {
        final matchesSearch = search.isEmpty ||
            (p.vehicleLicensePlate?.toLowerCase().contains(search) ?? false) ||
            p.passCode.toLowerCase().contains(search);

        bool matchesStatus;
        if (statusFilter == null) {
          matchesStatus = true;
        } else if (statusFilter == 'Expired') {
          matchesStatus = p.status == 'Expired' || p.status == 'Revoked';
        } else {
          matchesStatus = p.status == statusFilter;
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _revokePass(ParkingPassModel pass) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hủy vé xe', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vé: ${pass.vehicleLicensePlate ?? pass.passCode}', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Lý do hủy *',
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
                showSnack(context, 'Vui lòng nhập lý do hủy', error: true);
                return;
              }
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Hủy vé', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _svc.revokePass(pass.id, reasonController.text.trim());
        if (mounted) {
          showSnack(context, 'Đã hủy vé thành công');
          _load();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi hủy vé: $e', error: true);
      }
    }
  }

  int _countByStatus(String status) {
    if (status == 'Expired') {
      return _allPasses.where((p) => p.status == 'Expired' || p.status == 'Revoked').length;
    }
    return _allPasses.where((p) => p.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Vé Giữ Xe', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
              onTap: (_) {}, 
              tabs: [
                Tab(text: 'Active (${_countByStatus('Active')})'),
                Tab(text: 'Pending (${_countByStatus('PendingPayment')})'),
                Tab(text: 'History (${_countByStatus('Expired')})'), 
                const Tab(text: 'All'),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredPasses.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Không có vé nào', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
                : RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    itemCount: _filteredPasses.length,
                    itemBuilder: (context, index) {
                      return _buildPassCard(_filteredPasses[index]);
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
                  Text('Quản lý Dịch vụ → Vé Giữ Xe', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Tổng số: ${_allPasses.length} vé', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                hintText: 'Tìm theo biển số, mã vé...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => _searchController.clear())
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: GoogleFonts.inter(color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassCard(ParkingPassModel pass) {
    Color statusColor;
    if (pass.status == 'Active') statusColor = Colors.green;
    else if (pass.status == 'PendingPayment') statusColor = Colors.orange;
    else if (pass.status == 'Revoked' || pass.status == 'Rejected') statusColor = Colors.red;
    else statusColor = Colors.grey;

    final daysRemaining = pass.daysRemaining;

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
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.confirmation_number, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pass.vehicleLicensePlate ?? 'N/A',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        pass.parkingPlanName ?? 'Vé tháng chung',
                        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
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
                  child: Text(
                    pass.statusText,
                    style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BẮT ĐẦU', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd/MM/yyyy').format(pass.validFrom), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                 Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('KẾT THÚC', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd/MM/yyyy').format(pass.validTo), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            
            if (pass.isActive && daysRemaining <= 7)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text('Hết hạn trong $daysRemaining ngày nữa', style: GoogleFonts.inter(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

             if (pass.revocationReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Lý do hủy: ${pass.revocationReason}', style: GoogleFonts.inter(color: Colors.red[700], fontSize: 13))),
                  ],
                ),
              ),
            ],

            if (pass.isActive) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _revokePass(pass),
                  icon: const Icon(Icons.cancel_presentation, size: 18),
                  label: const Text('Hủy vé'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}