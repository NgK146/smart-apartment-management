import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import 'users_service.dart';
import 'role_sheet.dart';
import 'user_detail_page.dart';

class AllUsersPage extends StatefulWidget {
  const AllUsersPage({super.key});

  @override
  State<AllUsersPage> createState() => _AllUsersPageState();
}

class _AllUsersPageState extends State<AllUsersPage> {
  final _svc = UsersService();
  List<UserLite> _items = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  // Màu chủ đạo (Teal)
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
      // Search null check
      final searchText = _searchController.text.trim();
      final (items, _) = await _svc.list(
        pageSize: 200,
        search: searchText.isEmpty ? null : searchText,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAssignRole(UserLite u) async {
    final role = await showRoleSheet(context);
    if (role == null) return;

    try {
      await _svc.assignRole(u.username, role);
      if (mounted) showSnack(context, 'Đã gán quyền "$role" cho ${u.username}');
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi gán quyền: $e', error: true);
    }
  }

  // Hàm lấy chữ cái đầu để làm Avatar
  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    return name.trim().split(' ').last[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Danh sách người dùng', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Header & Search Bar
          _buildHeader(),

          // 2. User List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: _primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
                itemCount: _items.length,
                itemBuilder: (context, index) => _buildUserCard(_items[index]),
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
        // Background Gradient
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
             boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('Quản trị hệ thống → Người dùng', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 5),
            Text('Tổng số: ${_items.length} tài khoản', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // Floating Search Bar
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
              decoration: InputDecoration(
                hintText: 'Tìm tên, username, email...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: GoogleFonts.inter(),
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(UserLite u) {
    final displayName = u.fullName?.isNotEmpty == true ? u.fullName! : u.username;
    final avatarChar = _getInitials(displayName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_)=> UserDetailPage(username: u.username)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Avatar (Initials)
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blueGrey.shade50,
                  child: Text(
                    avatarChar,
                    style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${u.username}',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey[400], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      // Email & Phone Row
                      if (u.email != null || u.phone != null)
                        Row(
                          children: [
                            if (u.email != null) ...[
                              Icon(Icons.email_outlined, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(child: Text(u.email!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                            ],
                            if (u.phone != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.phone_outlined, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(u.phone!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                            ]
                          ],
                        )
                    ],
                  ),
                ),

                // 3. Action Button (Gán Role)
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _handleAssignRole(u),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    foregroundColor: Colors.orange[800],
                  ),
                  tooltip: 'Phân quyền',
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
          Icon(Icons.person_search_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Không tìm thấy người dùng nào', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}
