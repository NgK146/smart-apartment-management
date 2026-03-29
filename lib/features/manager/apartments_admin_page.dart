import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../apartments/apartments_service.dart';

class ApartmentsAdminPage extends StatefulWidget {
  const ApartmentsAdminPage({super.key});
  @override
  State<ApartmentsAdminPage> createState() => _ApartmentsAdminPageState();
}

class _ApartmentsAdminPageState extends State<ApartmentsAdminPage> {
  final _svc = ApartmentsService();
  final _searchController = TextEditingController();

  List<Apartment> _allApartments = [];
  List<Apartment> _filteredApartments = [];
  bool _loading = true;
  String _currentFilter = 'All';

  // Modern Colors
  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _applyFilter() {
    setState(() {
      if (_currentFilter == 'All') {
        _filteredApartments = List.from(_allApartments);
      } else {
        _filteredApartments = _allApartments.where((a) => (a.status ?? '') == _currentFilter).toList();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await _svc.list(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim()
      );
      _allApartments = res;
      _applyFilter();
    } catch (e) {
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Actions ---
  Future<void> _createOrEdit([Apartment? item]) async {
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    final buildingCtrl = TextEditingController(text: item?.building ?? '');
    final floorCtrl = TextEditingController(text: item?.floor.toString() ?? '');
    final areaCtrl = TextEditingController(text: item?.areaM2?.toString() ?? '');
    String selectedStatus = item?.status ?? 'Available';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 24, right: 24, top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 24),
                      Text(item == null ? 'Thêm căn hộ mới' : 'Cập nhật căn hộ', 
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(codeCtrl, 'Mã căn hộ (P101)', Icons.meeting_room),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(buildingCtrl, 'Tòa nhà (A)', Icons.business),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(floorCtrl, 'Tầng số', Icons.layers, isNumber: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(areaCtrl, 'Diện tích (m²)', Icons.square_foot, isNumber: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Trạng thái hiện tại',
                          labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.info_outline, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF009688))),
                          filled: true, fillColor: Colors.grey[50],
                        ),
                        items: [
                          _buildDropdownItem('Available', '🟢 Còn trống (Available)'),
                          _buildDropdownItem('Occupied', '🔴 Đã có người (Occupied)'),
                          _buildDropdownItem('Maintenance', '🔧 Bảo trì (Maintenance)'),
                          _buildDropdownItem('Reserved', '🟡 Đã đặt (Reserved)'),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryColor, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Lưu thông tin', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );

    if (ok == true) {
      final newItem = Apartment(
        id: item?.id ?? '',
        code: codeCtrl.text.trim(),
        building: buildingCtrl.text.trim(),
        floor: int.tryParse(floorCtrl.text.trim()) ?? 0,
        areaM2: double.tryParse(areaCtrl.text.trim()),
        status: selectedStatus,
      );

      try {
        if (item == null) {
          await _svc.create(newItem);
          if (mounted) showSnack(context, 'Thêm căn hộ thành công', error: false);
        } else {
          await _svc.update(item.id, newItem);
          if (mounted) showSnack(context, 'Cập nhật căn hộ thành công', error: false);
        }
        await _loadData();
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi: $e', error: true);
      }
    }
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String text) {
    return DropdownMenuItem(
        value: value, 
        child: Text(text, style: GoogleFonts.inter(fontSize: 14))
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      ),
    );
  }

  Future<void> _delete(Apartment a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xóa căn hộ?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa căn hộ "${a.code}" thuộc tòa ${a.building}?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _svc.delete(a.id);
        if(!mounted) return;
        showSnack(context, 'Đã xóa căn hộ');
        await _loadData();
      } catch (e) {
        if(!mounted) return;
        showSnack(context, 'Lỗi: $e', error: true);
      }
    }
  }

  // --- Helper UI ---
  Color _getStatusColor(String? status) {
    if (status == null || status.isEmpty) return Colors.grey;
    switch (status) {
      case 'Available': return Colors.green;
      case 'Occupied': return Colors.blue; // Changed from redAccent for better vibe
      case 'Maintenance': return Colors.orange;
      case 'Reserved': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getStatusName(String? status) {
    if (status == null || status.isEmpty) return 'Chưa xác định';
    switch (status) {
      case 'Available': return 'Còn trống';
      case 'Occupied': return 'Đã ở';
      case 'Maintenance': return 'Bảo trì';
      case 'Reserved': return 'Đã đặt';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Quản lý căn hộ', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Thêm phòng', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 54, // Increased from 50 to prevent overflow
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFilterChip('all', 'Tất cả'),
                  _buildFilterChip('Available', 'Còn trống'),
                  _buildFilterChip('Occupied', 'Đã ở'),
                  _buildFilterChip('Maintenance', 'Bảo trì'),
                  _buildFilterChip('Reserved', 'Đã đặt'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredApartments.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                   color: _primaryColor,
                   onRefresh: _loadData,
                    child: ListView.builder(
              padding: const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 80),
              itemCount: _filteredApartments.length,
              itemBuilder: (_, i) => _buildApartmentCard(_filteredApartments[i]),
            ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _currentFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentFilter = key;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade300,
            ),
            boxShadow: isSelected 
                ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Tìm theo mã phòng hoặc tòa nhà...',
            hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onSubmitted: (_) => _loadData(),
        ),
      ),
    );
  }

  Widget _buildApartmentCard(Apartment a) {
    final statusColor = _getStatusColor(a.status);
    final statusName = _getStatusName(a.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material( // Add Material for ink ripple
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _createOrEdit(a),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    a.building,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blueGrey),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Phòng ${a.code}',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusName,
                            style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.layers_outlined, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('Tầng ${a.floor}', 
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 14, color: Colors.grey[200]),
                        const SizedBox(width: 8),
                        Icon(Icons.square_foot, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('${a.areaM2?.toStringAsFixed(0) ?? "?"} m²', 
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                onPressed: () => _delete(a),
              )
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
             padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.apartment_rounded, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Không tìm thấy căn hộ nào',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}