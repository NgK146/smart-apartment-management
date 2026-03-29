// lib/app_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/profile_page.dart';
import '../amenities/amenities_page.dart';
import '../billing/invoices_page.dart';
import '../complaints/complaints_page.dart';
import '../notifications/user_notifications_page.dart';
import '../notifications/user_notifications_service.dart';
import '../ai/smart_ai_page.dart';
import 'package:icitizen_app/features/security/access_control_page.dart' as security;
import '../../core/services/notification_signalr_service.dart';
import '../../core/services/deep_link_service.dart';
import 'home_page.dart'; // <-- Trang chủ đã nâng cấp

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}


class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _notificationsService = userNotificationsService;
  int _unreadNotifications = 0;
  static const _notifLastSeenKey = 'last_seen_notification_at';

  // [NÂNG CẤP] Danh sách các trang và tiêu đề tương ứng
  late final List<Widget> _pages;
  final List<String> _titles = [
    'Trang chủ',
    'Thông báo',
    'Phản ánh',
    'Hoá đơn',
    'Tiện ích'
  ];

  @override
  void initState() {
    super.initState();

    // [NÂNG CẤP] Khởi tạo _pages ở đây
    // Chúng ta truyền một hàm callback vào HomePage
    // để nó có thể điều khiển việc chuyển tab của AppShell
    _pages = [
      HomePage(onNavigateToTab: (tabIndex) {
        setState(() => _index = tabIndex);
      }),
      const UserNotificationsPage(),
      const ComplaintsPage(),
      const InvoicesPage(),
      const AmenitiesPage()
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthState>();
      auth.loadProfile();
      _initNotificationBadge();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh badge khi dependencies thay đổi (ví dụ: quay lại từ trang khác)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBadgeIfNeeded();
    });
  }

  Future<void> _refreshBadgeIfNeeded() async {
    // Chỉ refresh nếu đang không ở trang thông báo để tránh conflict
    if (_index != 1) {
      try {
        final res = await _notificationsService.list(page: 1, pageSize: 1, unreadOnly: true);
        if (mounted) {
          setState(() => _unreadNotifications = res.unreadCount);
        }
      } catch (_) {
        // Bỏ qua lỗi
      }
    }
  }

  StreamSubscription? _notificationSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotificationBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await _notificationsService.list(page: 1, pageSize: 1, unreadOnly: true);
      if (!mounted) return;
      setState(() => _unreadNotifications = res.unreadCount);

      // realtime - đảm bảo chỉ subscribe một lần
      if (_notificationSubscription == null) {
        await notificationSignalRService.connect();
        _notificationSubscription = notificationSignalRService.stream.listen((data) {
          final unread = data['unreadCount'] as int?;
          if (unread != null && mounted) {
            setState(() => _unreadNotifications = unread);
          }
        });
      }

      // Listen deep links for payment redirects
      if (_deepLinkSubscription == null) {
        _deepLinkSubscription = deepLinkService.deepLinkStream.listen((uri) {
          if (mounted) _handleDeepLink(uri);
        });
      }

      prefs.setString(
        _notifLastSeenKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }
  
  /// Handle deep link from payment redirect
  void _handleDeepLink(Uri uri) {
    try {
      debugPrint('🔗 Deep link received: $uri');
      
      // Format: icitizen://payment/success?orderCode=123&invoiceId=abc
      if (uri.scheme == 'icitizen' && uri.host == 'payment') {
        final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        final invoiceId = uri.queryParameters['invoiceId'];
        final orderCode = uri.queryParameters['orderCode'];
        
        if (path == 'success') {
          // Navigate to invoices page with highlight
          setState(() => _index = 3); // Tab hóa đơn
          
          if (invoiceId != null) {
            // Replace invoices page with highlighted invoice
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => InvoicesPage(highlightInvoiceId: invoiceId),
                  ),
                );
              }
            });
          }
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Thanh toán thành công! ${orderCode != null ? "Mã: $orderCode" : ""}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (path == 'failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Thanh toán thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (path == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Đã hủy thanh toán'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Deep link error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final hasApartment =
        auth.apartmentCode != null && auth.apartmentCode!.isNotEmpty && auth.apartmentCode != '0';
    final isVerified = auth.isResidentVerified;

    return Scaffold(
      appBar: AppBar(
        // [NÂNG CẤP] Tiêu đề động dựa trên tab
        title: Text(
          _titles[_index],
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        // Nút chuông trung tâm thông báo / hoạt động
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              setState(() => _index = 1);
              // Không tự động đánh dấu đã đọc khi click vào icon
              // Chỉ chuyển sang trang thông báo, người dùng sẽ tự đánh dấu đã đọc nếu muốn
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ),
              ],
            ),
          ),
        ],
        // [NÂNG CẤP] Xoá nút logout ở đây vì đã có trong Drawer
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Khi vào trang thông báo, refresh badge để cập nhật số lượng
          if (i == 1) {
            _initNotificationBadge();
          } else {
            // Khi rời khỏi trang thông báo, refresh badge để cập nhật số lượng mới
            _refreshBadgeIfNeeded();
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Thông báo'),
          NavigationDestination(
              icon: Icon(Icons.report_outlined),
              selectedIcon: Icon(Icons.report),
              label: 'Phản ánh'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Hoá đơn'),
          NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available),
              label: 'Tiện ích'),
        ],
      ),
      drawer: Builder(
        builder: (drawerContext) => Drawer(
          child: SafeArea(
            child: Column(children: [
              // Header của Drawer (giữ nguyên, đã khá tốt)
              _buildDrawerHeader(context, auth, hasApartment, isVerified),

              // [NÂNG CẤP] Dọn dẹp các mục bị trùng với BottomNav
              // Chỉ giữ lại các mục không có ở thanh điều hướng dưới
              
              // Wrap menu items in Expanded + SingleChildScrollView to prevent overflow
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Hồ sơ'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfilePage()),
                            );
                          }),
                      ListTile(
                          leading: const Icon(Icons.directions_car_outlined),
                          title: const Text('Xe & thẻ'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/vehicles');
                          }),
                      ListTile(
                          leading: const Icon(Icons.apartment_outlined),
                          title: const Text('Căn hộ'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/apartments');
                          }),
                      ListTile(
                          leading: const Icon(Icons.support_agent_outlined),
                          title: const Text('Liên hệ BQL'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/contacts');
                          }),
                      ListTile(
                          leading: const Icon(Icons.live_help_outlined),
                          title: const Text('Hỗ trợ'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/support');
                          }),
                      ListTile(
                          leading: const Icon(Icons.forum_outlined),
                          title: const Text('Chat cộng đồng'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/chat');
                          }),
                      ListTile(
                          leading: const Icon(Icons.store_outlined),
                          title: const Text('Khu Chợ Nội Khu'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/marketplace');
                          }),
                      ListTile(
                          leading: const Icon(Icons.bolt_outlined),
                          title: const Text('SmartHome AI'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SmartAiPage()),
                            );
                          }),
                      ListTile(
                          leading: const Icon(Icons.lock_outlined),
                          title: const Text('Kiểm Soát Truy Cập'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AccessControlEntry()),
                            );
                          }),
                      ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const Text('Gói hàng - Locker'),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            Navigator.pushNamed(context, '/locker/resident/packages');
                          }),

                      // Nút "Trở thành Người bán" hoặc "Quản lý Cửa hàng"
                      if (!auth.roles.contains('Seller'))
                   

                        ListTile(
                            leading: const Icon(Icons.storefront_outlined),
                            title: const Text('Trở thành Người bán'),
                            onTap: () {
                              Navigator.pop(drawerContext);
                              Navigator.pushNamed(context, '/store-registration');
                            })
                      else
                        ListTile(
                            leading: const Icon(Icons.dashboard_outlined),
                            title: const Text('Quản lý Cửa hàng'),
                            onTap: () {
                              Navigator.pop(drawerContext);
                              Navigator.pushNamed(context, '/my-store');
                            }),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),
              
              // Theme Toggle
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDark = themeProvider.isDarkMode;
                  return ListTile(
                    leading: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        key: ValueKey(isDark),
                      ),
                    ),
                    title: Text(isDark ? 'Chế độ sáng' : 'Chế độ tối'),
                    subtitle: Text(
                      isDark ? 'Đang dùng giao diện tối' : 'Đang dùng giao diện sáng',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    onTap: () {
                      themeProvider.toggleTheme();
                    },
                  );
                },
              ),
              
              const Divider(height: 1),
              ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Đăng xuất'),
                  onTap: () {
                    auth.logout();
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (_) => false);
                  })
            ]),
          ),
        ),
      ),
    );
  }

  // Widget header của Drawer
  Widget _buildDrawerHeader(BuildContext context, AuthState auth,
      bool hasApartment, bool isVerified) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.fullName ?? auth.username ?? '',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Role: ${auth.roles.join(", ")}',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ])),
          ]),
          if (hasApartment) ...[
            const SizedBox(height: 8),
            _buildStatusChip(
              context,
              icon: Icons.home,
              label: 'Căn hộ: ${auth.apartmentCode}',
              isVerified: isVerified,
            )
          ] else ...[
            const SizedBox(height: 8),
            _buildStatusChip(context,
                icon: Icons.info_outline,
                label: 'Chưa liên kết căn hộ',
                isVerified: false,
                isWarning: true)
          ],
        ],
      ),
    );
  }

  // Chip trạng thái nhỏ trong Drawer
  Widget _buildStatusChip(BuildContext context,
      {required IconData icon,
        required String label,
        bool isVerified = true,
        bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isWarning ? Colors.white70 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isVerified && !isWarning) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Chờ duyệt',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wrapper to reference the AccessControlPage from the security feature.
class AccessControlEntry extends StatelessWidget {
  const AccessControlEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return security.AccessControlPage();
  }
}