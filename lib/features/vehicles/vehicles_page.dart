import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../auth/auth_provider.dart';
import 'vehicles_service.dart';
import 'vehicle_model.dart';
import 'parking_pass_model.dart';
import 'parking_pass_detail_page.dart';
import 'register_pass_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> with SingleTickerProviderStateMixin {
  final _svc = VehiclesService();
  final _items = <VehicleModel>[];
  final _passes = <ParkingPassModel>[];
  bool _loading = true;
  bool _loadingPasses = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild để cập nhật FAB
    });
    _load();
    _loadPasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Với cư dân, API tự lấy danh sách xe theo tài khoản hiện tại,
      // không cần (và không nên) truyền residentProfileId = userId,
      // tránh lọc sai và trả về rỗng.
      final list = await _svc.list();
      if (mounted) setState(() => _items..clear()..addAll(list));
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải danh sách xe: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPasses() async {
    setState(() => _loadingPasses = true);
    try {
      final list = await _svc.listPasses(status: 'Active');
      if (mounted) setState(() => _passes..clear()..addAll(list));
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải vé xe: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingPasses = false);
    }
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    if (!vehicle.canEdit) {
      showSnack(context, 'Chỉ có thể xóa xe đang chờ duyệt', error: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa xe ${vehicle.licensePlate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _svc.delete(vehicle.id);
        if (mounted) {
          showSnack(context, 'Đã xóa xe thành công');
          _load();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Lỗi xóa xe: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xe & thẻ ra vào',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            }
          },
          tooltip: 'Quay lại',
        ),
        toolbarHeight: 56,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                ? [
                    const Color(0xFF1A237E),
                    const Color(0xFF4A148C),
                    const Color(0xFF006064),
                  ]
                : [
                    const Color(0xFF0091EA),
                    const Color(0xFF00B8D4),
                    const Color(0xFF00BFA5),
                  ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car_outlined), text: 'Xe của tôi'),
            Tab(icon: Icon(Icons.confirmation_number), text: 'Vé xe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVehiclesTab(),
          _buildPassesTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddVehicleDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm xe mới'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _handleRegisterPass(),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Đăng ký vé xe'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              break;
            case 1:
              Navigator.of(context).pushReplacementNamed('/notifications');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/complaints');
              break;
            case 3:
              Navigator.of(context).pushReplacementNamed('/invoices');
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/amenities');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Thông báo'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Phản ánh'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Hoá đơn'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: 'Tiện ích'),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Chưa có xe nào', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Nhấn nút + để thêm xe mới', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
        itemBuilder: (context, index) {
          final vehicle = _items[index];
          return _buildVehicleCard(vehicle);
        },
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final theme = Theme.of(context);
    final statusColor = vehicle.status == 'Approved'
        ? Colors.green
        : vehicle.status == 'Rejected'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: vehicle.canEdit ? () => _showEditVehicleDialog(vehicle) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getVehicleIcon(vehicle.vehicleType), color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.licensePlate,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle.vehicleType}${vehicle.color != null ? ' • ${vehicle.color}' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      vehicle.statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (vehicle.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lý do: ${vehicle.rejectionReason}',
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (vehicle.canEdit) ...[
                    TextButton.icon(
                      onPressed: () => _showEditVehicleDialog(vehicle),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Sửa'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteVehicle(vehicle),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Xóa'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                  const Spacer(),
                  if (vehicle.canBuyPass)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterPassPage(vehicle: vehicle),
                          ),
                        ).then((_) => _loadPasses());
                      },
                      icon: const Icon(Icons.shopping_cart, size: 18),
                      label: const Text('Mua vé'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassesTab() {
    if (_loadingPasses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_passes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Chưa có vé xe nào', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Đăng ký mua vé cho xe đã được duyệt', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _passes.length,
        itemBuilder: (context, index) {
          final pass = _passes[index];
          return _buildPassCard(pass);
        },
      ),
    );
  }

  Widget _buildPassCard(ParkingPassModel pass) {
    final theme = Theme.of(context);
    final isExpiringSoon = pass.needsRenewal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParkingPassDetailPage(pass: pass),
            ),
          ).then((_) => _loadPasses());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isExpiringSoon ? Colors.orange.withOpacity(0.1) : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.confirmation_number,
                      color: isExpiringSoon ? Colors.orange : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pass.vehicleLicensePlate ?? 'N/A',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pass.parkingPlanName ?? 'N/A',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isExpiringSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sắp hết hạn',
                        style: TextStyle(color: Colors.orange[700], fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Hết hạn: ${_formatDate(pass.validTo)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  if (pass.daysRemaining > 0)
                    Text(
                      'Còn ${pass.daysRemaining} ngày',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isExpiringSoon ? Colors.orange[700] : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddVehicleDialog() {
    _showVehicleFormDialog();
  }

  Future<void> _handleRegisterPass() async {
    // Kiểm tra xem có xe nào đã được duyệt không
    final approvedVehicles = _items.where((v) => v.status == 'Approved').toList();
    
    if (approvedVehicles.isEmpty) {
      // Hiển thị dialog thông báo
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chưa có xe được duyệt'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bạn cần thêm xe và chờ duyệt trước khi đăng ký vé.'),
              SizedBox(height: 16),
              Text(
                'Vui lòng thêm thông tin xe ở tab "Xe của tôi" và chờ Admin duyệt.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
                _tabController.animateTo(0); // Chuyển sang tab "Xe của tôi"
              },
              child: const Text('Thêm xe ngay'),
            ),
          ],
        ),
      );
      
      if (shouldAdd == true) {
        // Chuyển sang tab "Xe của tôi" và mở dialog thêm xe
        Future.delayed(const Duration(milliseconds: 300), () {
          _showAddVehicleDialog();
        });
      }
    } else if (approvedVehicles.length == 1) {
      // Chỉ có 1 xe được duyệt, chuyển thẳng đến trang đăng ký
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterPassPage(vehicle: approvedVehicles.first),
        ),
      ).then((_) => _loadPasses());
    } else {
      // Có nhiều xe được duyệt, cho phép chọn xe
      final selectedVehicle = await showDialog<VehicleModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn xe để đăng ký vé'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: approvedVehicles.length,
              itemBuilder: (context, index) {
                final vehicle = approvedVehicles[index];
                return ListTile(
                  leading: Icon(_getVehicleIcon(vehicle.vehicleType)),
                  title: Text(vehicle.licensePlate),
                  subtitle: Text(vehicle.vehicleType),
                  onTap: () => Navigator.pop(context, vehicle),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
      
      if (selectedVehicle != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterPassPage(vehicle: selectedVehicle),
          ),
        ).then((_) => _loadPasses());
      }
    }
  }

  void _showEditVehicleDialog(VehicleModel vehicle) {
    _showVehicleFormDialog(vehicle: vehicle);
  }

  void _showVehicleFormDialog({VehicleModel? vehicle}) {
    final licensePlateController = TextEditingController(text: vehicle?.licensePlate);
    final brandController = TextEditingController(text: vehicle?.brand);
    final modelController = TextEditingController(text: vehicle?.model);
    final colorController = TextEditingController(text: vehicle?.color);
    String selectedType = vehicle?.vehicleType ?? 'Xe máy';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(vehicle == null ? 'Thêm xe mới' : 'Sửa thông tin xe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: licensePlateController,
                  decoration: const InputDecoration(
                    labelText: 'Biển số xe *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Loại xe *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Xe máy', child: Text('Xe máy')),
                    DropdownMenuItem(value: 'Ô tô', child: Text('Ô tô')),
                    DropdownMenuItem(value: 'Xe đạp', child: Text('Xe đạp')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: brandController,
                  decoration: const InputDecoration(
                    labelText: 'Hãng xe',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Màu sắc',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (licensePlateController.text.trim().isEmpty) {
                        showSnack(context, 'Vui lòng nhập biển số xe', error: true);
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        final auth = context.read<AuthState>();
                        final vehicleData = VehicleModel(
                          id: vehicle?.id ?? '',
                          licensePlate: licensePlateController.text.trim(),
                          vehicleType: selectedType,
                          brand: brandController.text.trim().isEmpty ? null : brandController.text.trim(),
                          model: modelController.text.trim().isEmpty ? null : modelController.text.trim(),
                          color: colorController.text.trim().isEmpty ? null : colorController.text.trim(),
                          residentProfileId: auth.userId ?? '',
                          isActive: true,
                          status: vehicle?.status ?? 'Pending',
                          createdAtUtc: vehicle?.createdAtUtc ?? DateTime.now(),
                        );

                        if (vehicle == null) {
                          await _svc.create(vehicleData);
                          if (mounted) {
                            showSnack(context, 'Đã thêm xe thành công. Vui lòng chờ duyệt.');
                            Navigator.pop(context);
                            _load();
                          }
                        } else {
                          await _svc.update(vehicle.id, vehicleData);
                          if (mounted) {
                            showSnack(context, 'Đã cập nhật thông tin xe');
                            Navigator.pop(context);
                            _load();
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          showSnack(context, 'Lỗi: $e', error: true);
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(vehicle == null ? 'Thêm' : 'Lưu'),
            ),
          ],
        ),
                ),
    );
  }

  /// Chọn icon phù hợp theo loại xe hiển thị từ API (Xe máy, Ô tô, Xe đạp, ...)
  IconData _getVehicleIcon(String vehicleType) {
    final type = vehicleType.toLowerCase();
    if (type.contains('máy') || type.contains('motor') || type.contains('xe máy')) {
      return Icons.two_wheeler;
    }
    if (type.contains('đạp') || type.contains('bike') || type.contains('xe đạp')) {
      return Icons.pedal_bike;
    }
    // Mặc định là ô tô
    return Icons.directions_car;
  }
}
