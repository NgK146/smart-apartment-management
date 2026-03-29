import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'users_service.dart';
import 'role_sheet.dart';
import 'user_detail_page.dart';

class PendingUsersPage extends StatefulWidget {
  const PendingUsersPage({super.key});

  @override
  State<PendingUsersPage> createState() => _PendingUsersPageState();
}

class _PendingUsersPageState extends State<PendingUsersPage> {
  final _svc = UsersService();
  List<UserLite> _pendingItems = [];
  List<UserLite> _filteredItems = []; // Danh sách để hiển thị (sau khi search)
  bool _loading = true;
  final _searchController = TextEditingController();

  // Màu chủ đạo
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final (items, _) = await _svc.list(pageSize: 200);
      // Chỉ lấy những user chưa approve
      _pendingItems = items.where((u) => !u.isApproved).toList();
      _filterData(); // Apply search ban đầu
    } catch (e) {
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Hàm lọc dữ liệu local (vì đã tải hết về rồi)
  void _filterData() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredItems = _pendingItems);
    } else {
      setState(() {
        _filteredItems = _pendingItems.where((u) {
          return (u.username.toLowerCase().contains(query)) ||
              (u.fullName?.toLowerCase().contains(query) ?? false) ||
              (u.email?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  Future<void> _handleApprove(UserLite u) async {
    try {
      await _svc.approve(u.username);
      showSnack(context, 'Đã duyệt tài khoản ${u.username}');
      _loadData(); // Reload lại list
    } catch (e) {
      showSnack(context, 'Duyệt lỗi: $e', error: true);
    }
  }

  Future<void> _handleAssignRole(UserLite u) async {
    final role = await showRoleSheet(context);
    if (role == null) return;
    try {
      await _svc.assignRole(u.username, role);
      showSnack(context, 'Đã gán role $role cho ${u.username}');
      // Thường gán role xong thì chưa chắc đã approve, tùy logic business của bạn.
      // Nếu gán role xong muốn reload để thấy thay đổi thì gọi _loadData();
    } catch (e) {
      showSnack(context, 'Lỗi gán quyền: $e', error: true);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    return name.trim().split(' ').last[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // 1. Header & Search
          _buildHeader(),

          // 2. List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: _primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) => _buildPendingCard(_filteredItems[index]),
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
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Yêu cầu đăng ký', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Duyệt tài khoản', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Đang chờ: ${_filteredItems.length} người', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterData(), // Filter ngay khi gõ
              decoration: InputDecoration(
                hintText: 'Tìm người chờ duyệt...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                  _searchController.clear();
                  _filterData();
                })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(UserLite u) {
    final displayName = u.fullName?.isNotEmpty == true ? u.fullName! : u.username;
    final initial = _getInitials(displayName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Phần trên: Thông tin
          InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailPage(username: u.username)));
              _loadData(); // Reload nếu có thay đổi trong detail
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange.shade50,
                    child: Text(initial, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Badge Requested Role
                            if (u.requestedRole != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.purple.withOpacity(0.2)),
                                ),
                                child: Text(
                                  u.requestedRole!,
                                  style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('@${u.username}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (u.email != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.email_outlined, size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(u.email!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ]),
                            if (u.phone != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.phone_outlined, size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(u.phone!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ]),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Đường kẻ ngang
          Divider(height: 1, color: Colors.grey[100]),

          // Phần dưới: Nút hành động
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Nút Gán quyền
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAssignRole(u),
                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                    label: const Text('Phân quyền'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nút Duyệt
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleApprove(u),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Duyệt ngay'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.how_to_reg_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Hết việc! Không có ai chờ duyệt.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}