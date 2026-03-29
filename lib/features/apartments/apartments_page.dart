import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../core/ui/snackbar.dart';
import '../auth/auth_provider.dart';
import '../resident/link_apartment_page.dart';
import 'apartments_service.dart';

class ApartmentsPage extends StatefulWidget {
  const ApartmentsPage({super.key});

  @override
  State<ApartmentsPage> createState() => _ApartmentsPageState();
}

class _ApartmentsPageState extends State<ApartmentsPage> {
  final _svc = ApartmentsService();
  final _searchController = TextEditingController();
  List<Apartment> _allApartments = [];
  List<Apartment> _filteredApartments = [];
  bool _loading = true;
  String? _selectedBuilding;
  String? _selectedStatus;
  final List<String> _buildings = [];
  final List<String> _statuses = ['Tất cả', 'Có sẵn', 'Đã có người ở', 'Đang bảo trì', 'Đã đặt chỗ'];

  @override
  void initState() {
    super.initState();
    _loadApartments();
    _searchController.addListener(_filterApartments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApartments() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthState>();
      if (auth.isManagerLike) {
        // Admin/Manager: lấy tất cả căn hộ với status đầy đủ
        try {
          _allApartments = await _svc.list(pageSize: 200);
        } catch (e) {
          // Nếu lỗi 403, fallback về listForResident
          // Fallback to resident list if manager access fails
          debugPrint('Không thể lấy tất cả căn hộ, dùng listForResident: $e');
          _allApartments = await _svc.listForResident(pageSize: 200);
        }
      } else {
        // Resident: lấy tất cả căn hộ với status đầy đủ qua endpoint mới
        _allApartments = await _svc.listForResident(pageSize: 200);
      }
      // Lấy danh sách tòa nhà duy nhất
      _buildings.clear();
      _buildings.add('Tất cả');
      final buildings = _allApartments.map((a) => a.building).toSet().toList()..sort();
      _buildings.addAll(buildings.cast<String>());
      _filteredApartments = List.from(_allApartments);
    } catch (e) {
      if (mounted) {
        // Hiển thị lỗi nhưng không crash app
        final errorMsg = e.toString().contains('403') || e.toString().contains('Forbidden')
            ? 'Bạn không có quyền xem danh sách căn hộ. Vui lòng liên hệ Ban quản lý.'
            : 'Lỗi tải danh sách căn hộ: $e';
        showSnack(context, errorMsg, error: true);
        // Set empty list để UI vẫn hiển thị
        _allApartments = [];
        _filteredApartments = [];
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filterApartments() {
    final search = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredApartments = _allApartments.where((apt) {
        // Tìm kiếm theo mã căn hộ, tòa nhà
        final matchesSearch = search.isEmpty ||
            apt.code.toLowerCase().contains(search) ||
            apt.building.toLowerCase().contains(search);
        
        // Filter theo tòa nhà
        final matchesBuilding = _selectedBuilding == null ||
            _selectedBuilding == 'Tất cả' ||
            apt.building == _selectedBuilding;
        
        // Filter theo trạng thái
        final matchesStatus = _selectedStatus == null ||
            _selectedStatus == 'Tất cả' ||
            getStatusText(apt.status) == _selectedStatus;
        
        return matchesSearch && matchesBuilding && matchesStatus;
      }).toList();
    });
  }

  String getStatusText(String? status) {
    // Logic: Trạng thái căn hộ phải dựa vào status từ backend (global)
    // - null/empty/Available: "Có sẵn" (chưa ai liên kết)
    // - Occupied: "Đã có người ở" (đã có người liên kết)
    // - Maintenance: "Đang bảo trì" (admin đánh dấu)
    // - Reserved: "Đã đặt chỗ" (đã đặt cọc)
    
    if (status == null || status.isEmpty) {
      // Chưa có ai liên kết → Có sẵn
      return 'Có sẵn';
    }
    
    switch (status) {
      case 'Available':
        return 'Có sẵn';
      case 'Occupied':
        return 'Đã có người ở';
      case 'Maintenance':
        return 'Đang bảo trì';
      case 'Reserved':
        return 'Đã đặt chỗ';
      default:
        // Nếu status không khớp, mặc định là "Có sẵn" (chưa có ai sở hữu)
        return 'Có sẵn';
    }
  }

  Color getStatusColor(String? status) {
    // Nếu status null hoặc rỗng, mặc định màu xanh (Available)
    if (status == null || status.isEmpty) {
      return Colors.green;
    }
    
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Occupied':
        return Colors.blue;
      case 'Maintenance':
        return Colors.orange;
      case 'Reserved':
        return Colors.purple;
      default:
        // Mặc định màu xanh cho trạng thái "Có sẵn"
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthState>();
    final hasApartment = auth.apartmentCode != null &&
        auth.apartmentCode!.isNotEmpty &&
        auth.apartmentCode != '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách căn hộ'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Căn hộ đã liên kết (nếu có)
          if (hasApartment)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.home, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Căn hộ của bạn',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.apartmentCode!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (!auth.isResidentVerified)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pending,
                                  size: 14,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Chờ duyệt',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LinkApartmentPage(),
                        ),
                      );
                      if (result == true && mounted) {
                        await auth.loadProfile();
                        await _loadApartments();
                      }
                    },
                    tooltip: 'Cập nhật căn hộ',
                  ),
                ],
              ),
            ),

          // Thanh tìm kiếm và filter
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm căn hộ...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBuilding ?? 'Tất cả',
                        decoration: InputDecoration(
                          labelText: 'Tòa nhà',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: _buildings.map((building) {
                          return DropdownMenuItem(
                            value: building,
                            child: Text(building),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBuilding = value;
                            _filterApartments();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus ?? 'Tất cả',
                        decoration: InputDecoration(
                          labelText: 'Trạng thái',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: _statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                            _filterApartments();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Danh sách căn hộ
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApartments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy căn hộ nào',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadApartments,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Responsive: số cột thay đổi theo kích thước màn hình
                            final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                            final isTablet = ResponsiveBreakpoints.of(context).isTablet;
                            final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
                            
                            return MasonryGridView.count(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredApartments.length,
                              itemBuilder: (_, i) {
                                final apt = _filteredApartments[i];
                                final isMyApartment = hasApartment &&
                                    auth.apartmentCode == apt.code;
                                return _ApartmentCard(
                                  apartment: apt,
                                  isMyApartment: isMyApartment,
                                  statusText: getStatusText(apt.status),
                                  statusColor: getStatusColor(apt.status),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: !hasApartment
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LinkApartmentPage(),
                  ),
                );
                if (result == true && mounted) {
                  await auth.loadProfile();
                  await _loadApartments();
                }
              },
              icon: const Icon(Icons.link),
              label: const Text('Liên kết căn hộ'),
            )
          : null,
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
}

class _ApartmentCard extends StatelessWidget {
  final Apartment apartment;
  final bool isMyApartment;
  final String statusText;
  final Color statusColor;

  const _ApartmentCard({
    required this.apartment,
    required this.isMyApartment,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isMyApartment ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMyApartment
            ? BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isMyApartment
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.home,
                  color: isMyApartment
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
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
                        Text(
                          apartment.code,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMyApartment) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Của bạn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tòa: ${apartment.building} • Tầng: ${apartment.floor}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (apartment.areaM2 != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Diện tích: ${apartment.areaM2!.toStringAsFixed(0)} m²',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _showDetails(BuildContext context) {
    final auth = Provider.of<AuthState>(context, listen: false);
    final hasApartment = auth.apartmentCode != null &&
        auth.apartmentCode!.isNotEmpty &&
        auth.apartmentCode != '0';
    final isMyApartment = hasApartment && auth.apartmentCode == apartment.code;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ApartmentDetailsSheet(
        apartment: apartment,
        isMyApartment: isMyApartment,
      ),
    );
  }
}

class _ApartmentDetailsSheet extends StatelessWidget {
  final Apartment apartment;
  final bool isMyApartment;

  const _ApartmentDetailsSheet({
    required this.apartment,
    this.isMyApartment = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String getStatusText(String? status) {
      // Logic: Trạng thái căn hộ phải dựa vào status từ backend (global)
      // - null/empty/Available: "Có sẵn" (chưa ai liên kết)
      // - Occupied: "Đã có người ở" (đã có người liên kết)
      // - Maintenance: "Đang bảo trì" (admin đánh dấu)
      // - Reserved: "Đã đặt chỗ" (đã đặt cọc)
      
      if (status == null || status.isEmpty) {
        // Chưa có ai liên kết → Có sẵn
        return 'Có sẵn';
      }
      
      switch (status) {
        case 'Available':
          return 'Có sẵn';
        case 'Occupied':
          return 'Đã có người ở';
        case 'Maintenance':
          return 'Đang bảo trì';
        case 'Reserved':
          return 'Đã đặt chỗ';
        default:
          // Nếu status không khớp, mặc định là "Có sẵn" (chưa có ai sở hữu)
          return 'Có sẵn';
      }
    }

    Color getStatusColor(String? status) {
      // Nếu status null hoặc rỗng, mặc định màu xanh (Available)
      if (status == null || status.isEmpty) {
        return Colors.green;
      }
      
      switch (status) {
        case 'Available':
          return Colors.green;
        case 'Occupied':
          return Colors.blue;
        case 'Maintenance':
          return Colors.orange;
        case 'Reserved':
          return Colors.purple;
        default:
          // Mặc định màu xanh cho trạng thái "Có sẵn"
          return Colors.green;
      }
    }

    // Trạng thái căn hộ phải dựa vào status từ backend (global)
    // Không phụ thuộc vào user đang đăng nhập
    final statusText = getStatusText(apartment.status);
    final statusColor = getStatusColor(apartment.status);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.home,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apartment.code,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _DetailRow(
                      icon: Icons.business,
                      label: 'Tòa nhà',
                      value: apartment.building,
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.stairs,
                      label: 'Tầng',
                      value: apartment.floor.toString(),
                    ),
                    if (apartment.areaM2 != null) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.square_foot,
                        label: 'Diện tích',
                        value: '${apartment.areaM2!.toStringAsFixed(0)} m²',
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Thông tin trạng thái',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getStatusDescription(apartment.status, isMyApartment),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusDescription(String? status, bool isMyApartment) {
    // Mô tả trạng thái dựa vào status từ backend (global)
    // isMyApartment chỉ để hiển thị thông tin bổ sung, không ảnh hưởng đến status
    
    if (status == null || status.isEmpty) {
      return 'Căn hộ này hiện đang có sẵn và có thể được liên kết.';
    }
    
    switch (status) {
      case 'Available':
        return 'Căn hộ này hiện đang có sẵn và có thể được liên kết.';
      case 'Occupied':
        return 'Căn hộ này đã có cư dân đang sinh sống.';
      case 'Maintenance':
        return 'Căn hộ này đang được bảo trì, không thể liên kết tạm thời.';
      case 'Reserved':
        return 'Căn hộ này đã được đặt chỗ, đang chờ xác nhận.';
      default:
        // Mặc định mô tả "Có sẵn" cho các trường hợp không xác định
        return 'Căn hộ này hiện đang có sẵn và có thể được liên kết.';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

