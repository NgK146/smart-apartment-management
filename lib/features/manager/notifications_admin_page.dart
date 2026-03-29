import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_provider.dart';
import '../notifications/notifications_service.dart';
import '../notifications/notification_model.dart';
import 'notification_detail_screen.dart';

class NotificationsAdminPage extends StatefulWidget {
  const NotificationsAdminPage({super.key});

  @override
  State<NotificationsAdminPage> createState() => _NotificationsAdminPageState();
}

class _NotificationsAdminPageState extends State<NotificationsAdminPage> {
  final _svc = NotificationsService();
  final _searchController = TextEditingController();

  List<NotificationModel> _items = [];
  bool _loading = true;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
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
      final res = await _svc.list(
        page: 1,
        pageSize: 50,
        onlyActive: false,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() => _items = res);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([NotificationModel? item]) async {
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    final contentCtrl = TextEditingController(text: item?.content ?? '');
    String type = item?.type ?? 'General';
    DateTime? from = item?.effectiveFrom;
    DateTime? to = item?.effectiveTo;

    Future<DateTime?> pickDateTime(DateTime? initialDate) async {
      final now = DateTime.now();
      final datePart = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 2),
        initialDate: initialDate ?? now,
      );
      if (datePart == null) return initialDate;

      if (!mounted) return null;
      final timePart = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
      );

      return DateTime(
        datePart.year,
        datePart.month,
        datePart.day,
        timePart?.hour ?? 0,
        timePart?.minute ?? 0,
      );
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
           decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    Text(
                      item == null ? 'Tạo thông báo mới' : 'Chỉnh sửa thông báo',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(titleCtrl, 'Tiêu đề', Icons.title),
                    const SizedBox(height: 16),
                    _buildTextField(contentCtrl, 'Nội dung chi tiết', Icons.article_outlined, maxLines: 4),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: type,
                       decoration: InputDecoration(
                        labelText: 'Loại thông báo',
                         labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        prefixIcon: const Icon(Icons.category_outlined, color: Colors.grey),
                      ),
                      items: const ['General', 'PowerCut', 'WaterCut', 'LiftMaintenance', 'Event']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter()))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            icon: Icons.calendar_today,
                            label: from == null ? 'Hiệu lực từ' : DateFormat('dd/MM/yyyy HH:mm').format(from!),
                            onTap: () async {
                              final val = await pickDateTime(from);
                              setModalState(() => from = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateButton(
                            icon: Icons.event_busy,
                             label: to == null ? 'Đến ngày' : DateFormat('dd/MM/yyyy HH:mm').format(to!),
                            onTap: () async {
                              final val = await pickDateTime(to);
                              setModalState(() => to = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('LƯU THÔNG BÁO', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result == true) {
      final newItem = NotificationModel(
        id: item?.id ?? '',
        title: titleCtrl.text.trim(),
        content: contentCtrl.text.trim(),
        type: type,
        createdAt: DateTime.now(),
        effectiveFrom: from,
        effectiveTo: to,
      );

      try {
        if (item == null) {
          await _svc.create(newItem);
        } else {
          await _svc.update(item.id, newItem);
        }
        await _loadData();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu thành công!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
       style: GoogleFonts.inter(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[50],
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildDateButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(NotificationModel n) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Xác nhận xoá", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text("Bạn có chắc muốn xoá thông báo này không?", style: GoogleFonts.inter()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Huỷ", style: GoogleFonts.inter(color: Colors.grey))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text("Xoá", style: GoogleFonts.inter())),
          ],
        )
    );

    if (confirm == true) {
      await _svc.delete(n.id);
      await _loadData();
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'powercut': return Colors.orange;
      case 'watercut': return Colors.blue;
      case 'liftmaintenance': return Colors.purple;
      case 'event': return Colors.green;
      default: return Colors.teal;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'powercut': return Icons.flash_off_rounded;
      case 'watercut': return Icons.water_drop_rounded;
      case 'liftmaintenance': return Icons.elevator_rounded;
      case 'event': return Icons.event_rounded;
      default: return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Quản lý thông báo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              context.read<AuthState>().logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Thêm mới', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                   color: _primaryColor,
                   onRefresh: _loadData,
                  child: ListView.builder(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
              itemCount: _items.length,
              itemBuilder: (_, i) => _buildNotificationCard(_items[i]),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản trị viên → Thông báo', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Tổng số: ${_items.length} thông báo', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
              style: GoogleFonts.inter(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiêu đề, nội dung...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Chưa có thông báo nào', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel n) {
    final typeColor = _getTypeColor(n.type);
    final typeIcon = _getTypeIcon(n.type);
    
    // Status Logic
    final now = DateTime.now();
    String statusText = 'Đang hiện';
    Color statusColor = Colors.green;
    
    if (n.effectiveTo != null && n.effectiveTo!.isBefore(now)) {
      statusText = 'Đã hết hạn';
      statusColor = Colors.grey;
    } else if (n.effectiveFrom != null && n.effectiveFrom!.isAfter(now)) {
      statusText = 'Sắp hiện';
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            typeColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: n)));
            await _loadData();
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            typeColor,
                            typeColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(typeIcon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statusColor.withOpacity(0.15),
                                      statusColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) {
                                  if (value == 'edit') _createOrEdit(n);
                                  if (value == 'delete') _delete(n);
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 18), const SizedBox(width: 10), Text('Sửa', style: GoogleFonts.inter())])),
                                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 10), Text('Xóa', style: GoogleFonts.inter(color: Colors.red))])),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            n.title,
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.content,
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], height: 1.5),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.grey.shade200,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(_getTimeAgo(n.createdAt), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (n.likeCount > 0 || n.commentCount > 0) ...[
                      _buildStatItem(Icons.favorite, Colors.redAccent, '${n.likeCount}'),
                      const SizedBox(width: 15),
                      _buildStatItem(Icons.comment, Colors.blueAccent, '${n.commentCount}'),
                    ]
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
      ],
    );
  }
}