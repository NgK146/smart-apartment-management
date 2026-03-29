import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/ui/snackbar.dart';
import '../complaints/admin_complaints_service.dart';
import '../complaints/complaint_model.dart';

DateTime toVietnamTime(DateTime utcTime) {
  return utcTime.add(const Duration(hours: 7));
}

class ComplaintsAdminPage extends StatefulWidget {
  const ComplaintsAdminPage({super.key});

  @override
  State<ComplaintsAdminPage> createState() => _ComplaintsAdminPageState();
}

class _ComplaintsAdminPageState extends State<ComplaintsAdminPage> {
  final _svc = AdminComplaintsService();
  final _items = <ComplaintModel>[];
  final _sc = ScrollController();
  bool _loading = false;
  bool _done = false;
  int _page = 1;

  String? _selectedStatus;
  String? _selectedCategory;
  final _searchController = TextEditingController();

  Map<String, int> _stats = {};

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadStats();
    _load();
    _sc.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_sc.position.pixels > _sc.position.maxScrollExtent - 100 && !_loading && !_done) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _page = 1;
        _done = false;
        _items.clear();
      }
      final (data, total) = await _svc.list(
        page: _page,
        trangThai: _selectedStatus,
        loaiPhanAnh: _selectedCategory,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _items.addAll(data);
          if (data.length < 50 || _items.length >= total) _done = true;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải phản ánh: ${e.toString()}', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _svc.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore stats error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Quản lý Phản ánh', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: _primaryColor,
              onRefresh: () async {
                 await _load(refresh: true);
                 await _loadStats();
              },
              child: ListView.builder(
                controller: _sc,
                itemCount: _items.length + 1,
                padding: const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 80),
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loading
                            ? CircularProgressIndicator(color: _primaryColor)
                            : const SizedBox.shrink(),
                      ),
                    );
                  }
                  return _buildComplaintCard(_items[i]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalStats = _stats['tongSo'] ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 240, // Tăng chiều cao để chứa stats box
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
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
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duyệt & Phản hồi → Phản ánh', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('Tổng số: $totalStats phản ánh', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        
        // Stats Card
         Positioned(
          bottom: 80, // Cách bottom một khoảng để chừa chỗ cho Search Bar
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStat('Tổng số', _stats['tongSo'] ?? 0, Colors.blue),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                _buildCompactStat('Chờ XL', _stats['chuaXuLy'] ?? 0, Colors.orange),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                _buildCompactStat('Đã XL', _stats['daDong'] ?? 0, Colors.green),
              ],
            ),
          ),
        ),

        // Floating Search Bar
        Positioned(
          bottom: -28,
          left: 24,
          right: 24,
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
                hintText: 'Tìm kiếm phản ánh...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                 suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _load(refresh: true);
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _load(refresh: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Trạng thái',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: 'Pending', child: Text('Chưa xử lý')),
                DropdownMenuItem(value: 'InProgress', child: Text('Đang xử lý')),
                DropdownMenuItem(value: 'Resolved', child: Text('Đã xử lý')),
                DropdownMenuItem(value: 'Rejected', child: Text('Từ chối')),
              ],
              onChanged: (v) {
                setState(() => _selectedStatus = v);
                _load(refresh: true);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Loại',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: 'Sanitation', child: Text('Vệ sinh')),
                DropdownMenuItem(value: 'Security', child: Text('An ninh')),
                DropdownMenuItem(value: 'Service', child: Text('Dịch vụ')),
                DropdownMenuItem(value: 'Other', child: Text('Khác')),
              ],
              onChanged: (v) {
                setState(() => _selectedCategory = v);
                _load(refresh: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feedback_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Không có phản ánh nào',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel m) {
    Color statusColor;
    String statusText;
    switch (m.status) {
      case 'Pending':
        statusColor = Colors.orange;
        statusText = 'Chưa xử lý';
        break;
      case 'InProgress':
        statusColor = Colors.blue;
        statusText = 'Đang xử lý';
        break;
      case 'Resolved':
        statusColor = Colors.green;
        statusText = 'Đã xử lý';
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusText = 'Từ chối';
        break;
      default:
        statusColor = Colors.grey;
        statusText = m.status;
    }

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
      child: Material(
        color: Colors.transparent,
         borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _AdminComplaintDetail(m, _svc)),
            );
            if (result == true) {
              _load(refresh: true);
              _loadStats();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getCategoryIcon(m.category), color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  m.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(m.tenNguoiGui ?? 'Ẩn danh', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                    const Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(toVietnamTime(m.createdAtUtc)),
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sanitation': return Icons.cleaning_services_outlined;
      case 'Security': return Icons.local_police_outlined;
      case 'Service': return Icons.room_service_outlined;
      default: return Icons.report_problem_outlined;
    }
  }
}

class _ImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImageViewer({required this.urls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index].trim();
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminComplaintDetail extends StatefulWidget {
  final ComplaintModel complaint;
  final AdminComplaintsService service;
  const _AdminComplaintDetail(this.complaint, this.service);

  @override
  State<_AdminComplaintDetail> createState() => _AdminComplaintDetailState();
}

class _AdminComplaintDetailState extends State<_AdminComplaintDetail> {
  ComplaintModel? _detail;
  bool _loading = true;
  bool _updating = false;

  final _phanHoiController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _selectedStatus = widget.complaint.status;
  }

  @override
  void dispose() {
    _phanHoiController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      _detail = await widget.service.getDetails(widget.complaint.id);
      _selectedStatus = _detail?.status;
      _phanHoiController.text = _detail?.phanHoiAdmin ?? '';
    } catch (e) {
      if(mounted) showSnack(context, 'Lỗi tải chi tiết: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateComplaint() async {
    setState(() => _updating = true);
    try {
      await widget.service.update(
        id: widget.complaint.id,
        trangThai: _selectedStatus,
        phanHoiAdmin: _phanHoiController.text.trim().isEmpty ? null : _phanHoiController.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Đã cập nhật phản ánh thành công', error: false);
      Navigator.pop(context, true);
    } catch (e) {
      showSnack(context, 'Lỗi cập nhật: $e', error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteComplaint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa phản ánh này?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.delete(widget.complaint.id);
        if (!mounted) return;
        showSnack(context, 'Đã xóa phản ánh');
        Navigator.pop(context, true);
      } catch (e) {
        showSnack(context, 'Lỗi xóa: $e', error: true);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'InProgress': return Colors.blue;
      case 'Resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _detail ?? widget.complaint;
    final statusColor = _getStatusColor(m.status);
    final mediaUrls = _getMediaUrls(m);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Chi tiết phản ánh', style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
           IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[300]),
            onPressed: _deleteComplaint,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.feedback_outlined, 'Loại', m.category),
                  _buildDetailRow(Icons.calendar_today, 'Ngày gửi', DateFormat('dd/MM/yyyy HH:mm').format(toVietnamTime(m.createdAtUtc))),
                  _buildDetailRow(Icons.person_outline, 'Người gửi', m.tenNguoiGui ?? 'Ẩn danh'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Nội dung', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(m.content, style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: Colors.grey[800])),
            
            if (mediaUrls != null && mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Hình ảnh đính kèm', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: mediaUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageViewer(urls: mediaUrls, initialIndex: index))),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: NetworkImage(mediaUrls[index]), fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            
            Text('Xử lý phản ánh', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Trạng thái',
                labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Chưa xử lý')),
                DropdownMenuItem(value: 'InProgress', child: Text('Đang xử lý')),
                DropdownMenuItem(value: 'Resolved', child: Text('Đã xử lý')),
                DropdownMenuItem(value: 'Rejected', child: Text('Từ chối')),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phanHoiController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Phản hồi tới cư dân',
                labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _updating ? null : _updateComplaint,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _updating 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : Text('Cập nhật & Phản hồi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label:', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
  
  List<String>? _getMediaUrls(ComplaintModel m) {
    if (m.mediaUrls == null || m.mediaUrls!.isEmpty) return null;
    return m.mediaUrls!.split(';').where((s) => s.trim().isNotEmpty).toList();
  }
}