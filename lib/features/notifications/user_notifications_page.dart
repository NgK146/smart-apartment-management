import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/notification_signalr_service.dart';
import '../amenities/amenity_booking_detail_page.dart';
import '../manager/complaints_admin_page.dart';
import '../manager/concierge_requests_admin_page.dart';
import 'user_notification_model.dart';
import 'user_notifications_service.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({super.key});

  @override
  State<UserNotificationsPage> createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  final _service = userNotificationsService;
  final _scroll = ScrollController();
  final _items = <UserNotificationModel>[];
  String _filter = 'all';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
    notificationSignalRService.connect();
    notificationSignalRService.stream.listen((data) {
      final unread = data['unreadCount'] as int?;
      if (unread != null && mounted) {
        setState(() => _unreadCount = unread);
      }
      // prepend
      final id = data['id']?.toString();
      if (id != null) {
        setState(() {
          _items.insert(
              0,
              UserNotificationModel(
                id: id,
                title: data['title']?.toString() ?? '',
                message: data['message']?.toString() ?? '',
                type: data['type']?.toString() ?? '',
                refType: data['refType']?.toString(),
                refId: data['refId']?.toString(),
                createdAt: UserNotificationModel.parseUtcDateTime(data['createdAtUtc']?.toString() ?? DateTime.now().toUtc().toIso8601String()),
                readAt: null,
              ));
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.8 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _items.clear();
      });
    }
    setState(() => _loading = true);
    try {
      final res = await _service.list(page: _page, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _unreadCount = res.unreadCount;
        _hasMore = res.items.length >= 20;
      });
    } catch (e) {
      // tránh crash khi backend lỗi 500
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông báo: $e')),
      );
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await _service.list(page: nextPage, pageSize: 20);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(res.items);
        _hasMore = res.items.length >= 20;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = UserNotificationModel(
          id: _items[i].id,
          title: _items[i].title,
          message: _items[i].message,
          type: _items[i].type,
          refType: _items[i].refType,
          refId: _items[i].refId,
          createdAt: _items[i].createdAt,
          readAt: DateTime.now(),
        );
      }
      _unreadCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _items.where(_matchFilter).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _unreadCount > 0 ? 'Thông báo ($_unreadCount)' : 'Thông báo',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
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
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
                label: Text(
                  'Đánh dấu đọc',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Tất cả'),
                          const SizedBox(width: 8),
                          _buildFilterChip('complaint', 'Phản ánh'),
                          const SizedBox(width: 8),
                          _buildFilterChip('amenity', 'Tiện ích'),
                          const SizedBox(width: 8),
                          _buildFilterChip('payment', 'Thanh toán'),
                          const SizedBox(width: 8),
                          _buildFilterChip('other', 'Khác'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty && !_loading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Chưa có thông báo nào',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                ),
                                if (_filter != 'all')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Thử chọn bộ lọc khác',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                      controller: _scroll,
                      itemCount: filtered.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final n = filtered[index];
                        // Đảm bảo createdAt là UTC trước khi chuyển đổi
                        final createdAtUtc = n.createdAt.isUtc ? n.createdAt : n.createdAt.toUtc();
                        final createdLocal = _toVnTime(createdAtUtc);
                        
                        // Lấy thời gian hiện tại ở Việt Nam
                        final nowUtc = DateTime.now().toUtc();
                        final nowVn = _toVnTime(nowUtc);
                        
                        final (icon, color) = _iconFor(n);
                        
                        // So sánh với giờ Việt Nam hiện tại
                        final isToday = createdLocal.day == nowVn.day && 
                                       createdLocal.month == nowVn.month && 
                                       createdLocal.year == nowVn.year;
                        final yesterday = nowVn.subtract(const Duration(days: 1));
                        final isYesterday = createdLocal.day == yesterday.day &&
                                          createdLocal.month ==yesterday.month &&
                                          createdLocal.year == yesterday.year;
                        
                        String timeText;
                        final diff = nowVn.difference(createdLocal);
                        
                        if (isToday) {
                          timeText = DateFormat('HH:mm').format(createdLocal);
                        } else if (isYesterday) {
                          timeText = 'Hôm qua ${DateFormat('HH:mm').format(createdLocal)}';
                        } else if (diff.inDays < 7) {
                          timeText = DateFormat('dd/MM HH:mm').format(createdLocal);
                        } else {
                          timeText = DateFormat('dd/MM/yyyy HH:mm').format(createdLocal);
                        }
                        
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset((1 - value) * 50, 0),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                            gradient: !n.isRead
                              ? LinearGradient(
                                  colors: [
                                    color.withOpacity(isDark ? 0.08 : 0.06),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                            boxShadow: [
                              BoxShadow(
                                color: n.isRead 
                                  ? Colors.black.withOpacity(0.04)
                                  : color.withOpacity(0.2),
                                blurRadius: n.isRead ? 8 : 16,
                                offset: Offset(0, n.isRead ? 2 : 4),
                              ),
                            ],
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: n.isRead 
                                  ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                                  : color.withOpacity(0.3),
                                width: n.isRead ? 0.5 : 2,
                              ),
                            ),
                            color: n.isRead 
                              ? (isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white)
                              : (isDark ? theme.colorScheme.surface : Colors.white),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _openDetail(n),
                              splashColor: color.withOpacity(0.2),
                              highlightColor: color.withOpacity(0.1),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            color,
                                            color.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(icon, size: 28, color: Colors.white),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                                    color: theme.colorScheme.onSurface,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (!n.isRead)
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Colors.redAccent, Colors.deepOrangeAccent],
                                                    ),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.redAccent.withOpacity(0.6),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            n.message,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurfaceVariant,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  timeText,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  FilterChip _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
    );
  }

  bool _matchFilter(UserNotificationModel n) {
    // Nếu filter là 'all', hiển thị tất cả
    if (_filter == 'all') return true;
    final type = (n.type + ' ' + (n.refType ?? '')).toLowerCase();
    switch (_filter) {
      case 'complaint':
        return type.contains('complaint');
      case 'amenity':
        return type.contains('amenity');
      case 'payment':
        return type.contains('payment');
      case 'other':
        return !type.contains('complaint') && !type.contains('amenity') && !type.contains('payment');
      default:
        return true;
    }
  }

  Future<void> _openDetail(UserNotificationModel n) async {
    final wasUnread = !n.isRead;
    if (wasUnread) {
      await _service.markRead(n.id);
      if (mounted) {
        setState(() {
          final idx = _items.indexWhere((e) => e.id == n.id);
          if (idx != -1) {
            _items[idx] = UserNotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              refType: n.refType,
              refId: n.refId,
              createdAt: n.createdAt,
              readAt: DateTime.now(),
            );
          }
          _unreadCount = (_unreadCount - 1).clamp(0, 999);
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    n.message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(_toVnTime(n.createdAt)),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      label: const Text('Đóng'),
                    ),
                    const SizedBox(width: 12),
                    if ((n.refType ?? '').toLowerCase().contains('amenitybooking') && n.refId != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AmenityBookingDetailPage(bookingId: n.refId!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Xem đặt lịch'),
                      ),
                    if ((n.refType ?? '').toLowerCase().contains('complaint'))
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComplaintsAdminPage()),
                          );
                        },
                        icon: const Icon(Icons.report_outlined),
                        label: const Text('Xem phản ánh'),
                      ),
                    if ((n.refType ?? '').toLowerCase().contains('concierge'))
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ConciergeRequestsAdminPage()),
                          );
                        },
                        icon: const Icon(Icons.support_agent_outlined),
                        label: const Text('Yêu cầu concierge'),
                      ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  DateTime _toVnTime(DateTime utc) {
    // Chuyển đổi UTC sang giờ Việt Nam (UTC+7)
    // Đảm bảo DateTime là UTC trước khi cộng
    DateTime utcTime;
    if (utc.isUtc) {
      utcTime = utc;
    } else {
      // Nếu không phải UTC, giả sử nó là local time và chuyển sang UTC
      // Nhưng tốt nhất là đảm bảo input luôn là UTC
      utcTime = DateTime.utc(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second,
        utc.millisecond,
        utc.microsecond,
      );
    }
    // Cộng 7 giờ để chuyển sang giờ Việt Nam (UTC+7)
    final vnTime = utcTime.add(const Duration(hours: 7));
    return vnTime;
  }

  (IconData, Color) _iconFor(UserNotificationModel n) {
    final type = (n.type + ' ' + (n.refType ?? '')).toLowerCase();
    if (type.contains('complaint')) return (Icons.report_problem_outlined, Colors.deepOrange);
    if (type.contains('amenity')) return (Icons.event_available_outlined, Colors.blue);
    if (type.contains('payment')) return (Icons.receipt_long_outlined, Colors.teal);
    if (type.contains('concierge')) return (Icons.support_agent_outlined, Colors.purple);
    return (Icons.notifications_none, Colors.grey);
  }
}

