import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../vehicles/vehicles_service.dart';
import '../vehicles/parking_plan_model.dart';

extension ParkingPlanExtension on ParkingPlanModel {
  String get formattedPrice {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(price);
  }

  String get durationText {
    if (durationInDays == 30 || durationInDays == 31 || durationInDays == 28) {
      return '1 tháng';
    }
    return '$durationInDays ngày';
  }
}

class ParkingPlansAdminPage extends StatefulWidget {
  const ParkingPlansAdminPage({super.key});

  @override
  State<ParkingPlansAdminPage> createState() => _ParkingPlansAdminPageState();
}

class _ParkingPlansAdminPageState extends State<ParkingPlansAdminPage> {
  final _svc = VehiclesService();
  final _searchController = TextEditingController();
  List<ParkingPlanModel> _items = [];
  List<ParkingPlanModel> _filteredItems = [];
  bool _loading = true;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final search = _searchController.text.toLowerCase().trim();
    setState(() {
      if (search.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((plan) {
          return plan.name.toLowerCase().contains(search) ||
              (plan.description?.toLowerCase().contains(search) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await _svc.listPlans(pageSize: 200);
      if (mounted) setState(() {
        _filterItems();
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải danh sách gói vé: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([ParkingPlanModel? plan]) async {
    final nameController = TextEditingController(text: plan?.name ?? '');
    final descController = TextEditingController(text: plan?.description ?? '');
    final priceController = TextEditingController(text: plan?.price.toStringAsFixed(0) ?? '');
    final durationController = TextEditingController(text: plan?.durationInDays.toString() ?? '30');
    String selectedType = plan?.vehicleType ?? 'Xe máy';
    bool isActive = plan?.isActive ?? true;
    bool isSubmitting = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    plan == null ? 'Thêm gói vé mới' : 'Sửa gói vé',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildTextField(nameController, 'Tên gói vé *'),
                  const SizedBox(height: 16),
                  _buildTextField(descController, 'Mô tả', maxLines: 2),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    style: GoogleFonts.inter(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Loại xe *',
                      labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const ['Xe máy', 'Ô tô', 'Xe đạp']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField(priceController, 'Giá (VNĐ) *', keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(durationController, 'Thời hạn (ngày) *', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Text('Đang hoạt động', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Gói vé có sẵn để cư dân đăng ký', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                      value: isActive,
                      activeColor: _primaryColor,
                      onChanged: (value) => setModalState(() => isActive = value),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Hủy', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                              if (nameController.text.trim().isEmpty) {
                                showSnack(context, 'Vui lòng nhập tên gói vé', error: true);
                                return;
                              }
                              final price = double.tryParse(priceController.text);
                              if (price == null || price <= 0) {
                                showSnack(context, 'Giá không hợp lệ', error: true);
                                return;
                              }
                              final duration = int.tryParse(durationController.text);
                              if (duration == null || duration <= 0) {
                                showSnack(context, 'Thời hạn không hợp lệ', error: true);
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                final planData = ParkingPlanModel(
                                  id: plan?.id ?? '',
                                  name: nameController.text.trim(),
                                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                                  vehicleType: selectedType,
                                  price: price,
                                  durationInDays: duration,
                                  isActive: isActive,
                                  createdAtUtc: plan?.createdAtUtc ?? DateTime.now(),
                                );

                                if (plan == null) {
                                  await _svc.createPlan(planData);
                                  if (mounted) {
                                    showSnack(context, 'Đã thêm gói vé thành công');
                                    Navigator.pop(context, true);
                                  }
                                } else {
                                  await _svc.updatePlan(plan.id, planData);
                                  if (mounted) {
                                    showSnack(context, 'Đã cập nhật gói vé');
                                    Navigator.pop(context, true);
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  showSnack(context, 'Lỗi: $e', error: true);
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(plan == null ? 'Thêm' : 'Lưu', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      _load();
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _deletePlan(ParkingPlanModel plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa gói vé "${plan.name}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _svc.deletePlan(plan.id);
        if (mounted) {
          showSnack(context, 'Đã xóa gói vé');
          _load();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi xóa gói vé: $e', error: true);
      }
    }
  }

  IconData _getVehicleIcon(String type) {
    if (type.contains('Ô tô')) return Icons.directions_car_filled_rounded;
    if (type.contains('Xe máy')) return Icons.two_wheeler_rounded;
    if (type.contains('Xe đạp')) return Icons.pedal_bike_rounded;
    return Icons.confirmation_number_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Gói Vé Xe', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Thêm gói vé', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredItems.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Chưa có gói vé nào', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _load,
                  color: _primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 80),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildPlanCard(_filteredItems[index]);
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
                  Text('Quản lý dịch vụ → Vé Xe', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Tổng số: ${_items.length} gói vé', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                hintText: 'Tìm kiếm gói vé...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filterItems();
                  },
                )
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

  Widget _buildPlanCard(ParkingPlanModel plan) {
    final isInactive = !plan.isActive;
    final color = isInactive ? Colors.grey : _primaryColor;

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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getVehicleIcon(plan.vehicleType),
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isInactive ? Colors.grey[600] : Colors.black87),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isInactive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Đã tắt',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      if (plan.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan.description!,
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GIÁ VÉ', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      plan.formattedPrice,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('THỜI HẠN', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      plan.durationText,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createOrEdit(plan),
                    icon: Icon(Icons.edit, size: 18, color: _primaryColor),
                    label: Text('Chỉnh sửa', style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primaryColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 50,
                  child: OutlinedButton(
                    onPressed: () => _deletePlan(plan),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.delete, size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}