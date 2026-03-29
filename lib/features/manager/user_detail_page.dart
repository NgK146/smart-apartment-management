import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'users_service.dart';
import 'role_sheet.dart';
import 'package:intl/intl.dart';

class UserDetailPage extends StatefulWidget {
  final String username;
  const UserDetailPage({super.key, required this.username});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  final _svc = UsersService();
  Map<String, dynamic>? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _details = await _svc.getDetails(widget.username);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải thông tin: $e', error: true);
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    try {
      await _svc.approve(widget.username);
      if (!mounted) return;
      showSnack(context, 'Đã duyệt tài khoản');
      Navigator.pop(context, true); // Trả về true để refresh danh sách
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi duyệt: $e', error: true);
    }
  }

  Future<void> _assignRole() async {
    final role = await showRoleSheet(context);
    if (role == null) return;
    try {
      await _svc.assignRole(widget.username, role);
      if (!mounted) return;
      showSnack(context, 'Đã gán role $role cho ${widget.username}');
      await _load(); // Reload để cập nhật roles
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Gán role lỗi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết người dùng'),
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            )),
          ),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết người dùng')),
        body: const Center(child: Text('Không tìm thấy thông tin')),
      );
    }

    final d = _details!;
    final residentProfile = d['residentProfile'] as Map<String, dynamic>?;
    final apartment = residentProfile?['apartment'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết người dùng'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          )),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin tài khoản
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.person, color: theme.colorScheme.primary, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['fullName']?.toString() ?? d['username']?.toString() ?? 'N/A',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(
                                  d['isApproved'] == true ? 'Đã duyệt' : 'Chờ duyệt',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: d['isApproved'] == true 
                                    ? Colors.green.withOpacity(0.2) 
                                    : Colors.orange.withOpacity(0.2),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _InfoRow('Tên đăng nhập:', d['username']?.toString() ?? 'N/A'),
                    _InfoRow('Email:', d['email']?.toString() ?? 'N/A'),
                    _InfoRow('Số điện thoại:', d['phoneNumber']?.toString() ?? 'N/A'),
                    _InfoRow('Vai trò yêu cầu:', d['requestedRole']?.toString() ?? 'N/A'),
                    _InfoRow('Vai trò hiện tại:', (d['roles'] as List?)?.join(', ') ?? 'N/A'),
                    _InfoRow('Ngày tạo:', d['createdAtUtc'] != null 
                        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(d['createdAtUtc']).toLocal())
                        : 'N/A'),
                  ],
                ),
              ),
            ),
            
            // Thông tin cư dân (nếu có)
            if (residentProfile != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.home, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Thông tin cư dân',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow('CMND/CCCD:', residentProfile['nationalId']?.toString() ?? 'N/A', isImportant: true),
                      _InfoRow('Số điện thoại:', residentProfile['phone']?.toString() ?? 'N/A'),
                      _InfoRow('Email:', residentProfile['email']?.toString() ?? 'N/A'),
                      _InfoRow('Loại cư dân:', residentProfile['residentType']?.toString() ?? 'N/A'),
                      if (residentProfile['numResidents'] != null)
                        _InfoRow('Số người trong hộ:', residentProfile['numResidents'].toString()),
                      _InfoRow('Trạng thái xác minh:', residentProfile['isVerifiedByBQL'] == true ? 'Đã xác minh' : 'Chờ xác minh'),
                      if (residentProfile['dateJoined'] != null)
                        _InfoRow('Ngày tham gia:', DateFormat('dd/MM/yyyy').format(DateTime.parse(residentProfile['dateJoined']).toLocal())),
                    ],
                  ),
                ),
              ),
            ],

            // Thông tin căn hộ (nếu có)
            if (apartment != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apartment, color: theme.colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Thông tin căn hộ',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _InfoRow('Mã căn hộ:', apartment['code']?.toString() ?? 'N/A'),
                      _InfoRow('Tòa nhà:', apartment['building']?.toString() ?? 'N/A'),
                      _InfoRow('Tầng:', apartment['floor']?.toString() ?? 'N/A'),
                      if (apartment['areaM2'] != null)
                        _InfoRow('Diện tích:', '${apartment['areaM2']} m²'),
                    ],
                  ),
                ),
              ),
            ],

            // Nút hành động
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _assignRole,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Gán role'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: d['isApproved'] == true ? null : _approve,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Duyệt tài khoản'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isImportant;

  const _InfoRow(this.label, this.value, {this.isImportant = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isImportant ? theme.colorScheme.primary : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                color: isImportant ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

