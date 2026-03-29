import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../concierge/admin_concierge_service.dart';
import '../concierge/models/concierge_service.dart';
import '../../core/ui/snackbar.dart';

class ConciergeRequestsAdminPage extends StatefulWidget {
  const ConciergeRequestsAdminPage({super.key});

  @override
  State<ConciergeRequestsAdminPage> createState() => _ConciergeRequestsAdminPageState();
}

class _ConciergeRequestsAdminPageState extends State<ConciergeRequestsAdminPage> {
  final _svc = AdminConciergeService();
  final _items = <ConciergeRequest>[];
  final _scroll = ScrollController();
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _done = false;
  int _page = 1;
  String? _statusFilter;

  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');
  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 100 && !_loading && !_done) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _items.clear();
        _page = 1;
        _done = false;
      }
      final (data, total) = await _svc.list(
        page: _page,
        status: _statusFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        if (data.length < 20 || _items.length >= total) _done = true;
        _page++;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Không tải được danh sách yêu cầu concierge.';
      if (e.response?.statusCode == 404) {
        msg = 'API chưa được cấu hình (404).';
      }
      showSnack(context, msg, error: true);
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Lỗi kết nối.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(ConciergeRequest req, String status) async {
    try {
      await _svc.updateStatus(req.id, status);
      showSnack(context, 'Đã cập nhật trạng thái', error: false);
      await _load(refresh: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi cập nhật: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Yêu cầu Concierge', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                   color: _primaryColor,
                   onRefresh: () => _load(refresh: true),
                    child: ListView.builder(
              padding: const EdgeInsets.only(top: 0, left: 24, right: 24, bottom: 80),
              itemCount: _items.length + 1,
              itemBuilder: (_, i) {
                if (i == _items.length) {
                   return _loading 
                       ? Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _primaryColor)))
                       : const SizedBox.shrink();
                }
                return _buildCard(_items[i]);
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
          height: 180,
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
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Dịch vụ & Hỗ trợ → Concierge', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('Quản lý các yêu cầu từ cư dân', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
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
                hintText: 'Tìm theo tên dịch vụ, ghi chú...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
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

  Widget _buildFilterRow() {
    List<(String?, String)> statuses = [
      (null, 'Tất cả'),
      ('Pending', 'Chờ xử lý'),
      ('InProgress', 'Đang làm'),
      ('Completed', 'Hoàn thành'),
      ('Cancelled', 'Đã hủy'),
    ];
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 36, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
           final s = statuses[index];
           final isSelected = _statusFilter == s.$1;
           return InkWell(
            onTap: () {
              setState(() => _statusFilter = s.$1);
              _load(refresh: true);
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
              child: Center(
                child: Text(
                  s.$2,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(ConciergeRequestStatus status) {
    switch (status) {
      case ConciergeRequestStatus.pending: return Colors.orange;
      case ConciergeRequestStatus.inProgress: return Colors.blue;
      case ConciergeRequestStatus.completed: return Colors.green;
      case ConciergeRequestStatus.cancelled: return Colors.red;
    }
  }

  String _statusLabel(ConciergeRequestStatus status) {
    switch (status) {
      case ConciergeRequestStatus.pending: return 'Chờ xử lý';
      case ConciergeRequestStatus.inProgress: return 'Đang làm';
      case ConciergeRequestStatus.completed: return 'Hoàn thành';
      case ConciergeRequestStatus.cancelled: return 'Đã hủy';
    }
  }

  Widget _buildCard(ConciergeRequest r) {
    final statusColor = _statusColor(r.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.support_agent, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        r.serviceName.isNotEmpty ? r.serviceName : 'Dịch vụ #${r.serviceId}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(r.status),
                          style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow(Icons.person_outline, r.userName ?? 'Ẩn danh'),
            _buildDetailRow(Icons.access_time, 'Gửi lúc: ${_fmtDate.format(r.createdAtUtc.toLocal())}'),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
               const SizedBox(height: 12),
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                 child: Text(r.notes!, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800], fontStyle: FontStyle.italic)),
               ),
            ],

            if (r.status == ConciergeRequestStatus.pending || r.status == ConciergeRequestStatus.inProgress) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                   if (r.status == ConciergeRequestStatus.pending)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _changeStatus(r, 'InProgress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: Text('Tiếp nhận', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    if (r.status == ConciergeRequestStatus.inProgress)
                     Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _changeStatus(r, 'Completed'),
                         icon: const Icon(Icons.check, size: 18),
                        label: Text('Hoàn thành', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                    if (r.status != ConciergeRequestStatus.inProgress) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _changeStatus(r, 'Cancelled'),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text('Hủy bỏ', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade200),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Chưa có yêu cầu nào',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
