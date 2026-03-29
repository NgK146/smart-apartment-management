import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_signalr_service.dart';
import '../auth/auth_provider.dart';
import '../notifications/user_notifications_page.dart';
import '../notifications/user_notifications_service.dart';
import 'all_users_page.dart';
import 'amenities_admin_page.dart';
import 'amenity_bookings_admin_page.dart';
import 'apartments_admin_page.dart';
import 'complaints_admin_page.dart';
import 'fee_types_admin_page.dart';
import 'invoice_management_page.dart';
import 'manager_dashboard.dart';
import 'meter_readings_admin_page.dart';
import '../billing/admin_invoice_generator_page.dart';
import '../billing/blockchain_history_page.dart';
import 'notifications_admin_page.dart';
import 'parking_passes_admin_page.dart';
import 'parking_plans_admin_page.dart';
import 'pending_residents_page.dart';
import 'pending_users_page.dart';
import 'vehicles_admin_page.dart';
import '../chat/chat_page.dart';
import '../chat/conversation_list_screen.dart';
import '../marketplace/screens/admin/all_stores_page.dart';
import '../marketplace/screens/admin/marketplace_statistics_page.dart';
import '../marketplace/screens/admin/pending_stores_page.dart';
import 'concierge_requests_admin_page.dart';
import '../../core/theme/theme_provider.dart';

// Global key to access ManagerShell state from child widgets
final managerShellKey = GlobalKey<ManagerShellState>();

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});
  @override
  State<ManagerShell> createState() => ManagerShellState();
}

class ManagerShellState extends State<ManagerShell> {
  int _currentPageIndex = 0;
  // Index của BottomNav (0-4, với 4 là "Khác")
  int _navIndex = 0;

  // Public method to navigate to a specific page
  void navigateToPage(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
      _navIndex = 4; // Set to "Khác" tab
    });
  }

  final _notificationsService = userNotificationsService;
  int _newNotificationCount = 0;
  static const _notifLastSeenKeyManager = 'last_seen_notification_at_manager';

  final Map<int, Widget> _pageCache = {};
  List<Widget>? _cachedPagesList;

  @override
  void initState() {
    super.initState();
    _initNotificationBadge();
    notificationSignalRService.connect();
    notificationSignalRService.stream.listen((data) {
      final unread = data['unreadCount'] as int?;
      if (unread != null && mounted) {
        setState(() => _newNotificationCount = unread);
      }
    });
  }

  Future<void> _initNotificationBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final res = await _notificationsService.list(page: 1, pageSize: 1, unreadOnly: true);
      if (!mounted) return;
      setState(() => _newNotificationCount = res.unreadCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _newNotificationCount = 0);
    }
  }

  Widget _getPage(int index) {
    if (_pageCache.containsKey(index)) {
      return _pageCache[index]!;
    }
    Widget page;
    switch (index) {
      case 0: page = const ManagerDashboard(); break;
      case 1: page = const PendingUsersPage(); break;
      case 2: page = const AllUsersPage(); break;
      case 3: page = const ApartmentsAdminPage(); break;
      case 4: page = const PendingResidentsPage(); break;
      case 5: page = const AmenitiesAdminPage(); break;
      case 6: page = const AmenityBookingsAdminPage(); break;
      case 7: page = const ComplaintsAdminPage(); break;
      case 8: page = const NotificationsAdminPage(); break;
      case 9: page = const SupportTicketListScreen(); break;
      case 10: page = const ChatPage(); break;
      case 11: page = const VehiclesAdminPage(); break;
      case 12: page = const ParkingPlansAdminPage(); break;
      case 13: page = const ParkingPassesAdminPage(); break;
      case 14: page = const FeeTypesAdminPage(); break;
      case 15: page = const MeterReadingsAdminPage(); break;
      case 16: page = const InvoiceManagementPage(); break;
      case 17: page = const PendingStoresPage(); break;
      case 18: page = const AllStoresPage(); break;
      case 19:
        page = MarketplaceStatisticsPage(
          onBack: () {
            // Quay về dashboard khi nhấn nút back trong màn thống kê
            setState(() {
              _currentPageIndex = 0;
              _navIndex = 0;
            });
          },
        );
        break;
      case 20:
        page = const ConciergeRequestsAdminPage();
        break;
      case 21:
        page = const AdminInvoiceGeneratorPage();
        break;
      default: page = const ManagerDashboard(); break;
    }
    _pageCache[index] = page;
    _cachedPagesList = null; // Xóa cache list để build lại
    return page;
  }

  List<Widget> _buildPages() {
    if (_cachedPagesList != null &&
        _pageCache.length == _cachedPagesList!.length) {
      return _cachedPagesList!;
    }
    final pages = <Widget>[];
    _getPage(_currentPageIndex); // Đảm bảo trang hiện tại được cache
    for (int i = 0; i < 22; i++) {
      if (_pageCache.containsKey(i)) {
        pages.add(_pageCache[i]!);
      } else {
        pages.add(const SizedBox.shrink());
      }
    }
    _cachedPagesList = pages;
    return pages;
  }
  static const _primaryMap = [0, 2, 3, 8];

  // [REDESIGNED] Modern drawer sheet
  Future<void> _openMore() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Gradient Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF009688), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0xFF009688),
                              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quản trị viên',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'BQL Chung cư',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Menu Items
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernSection(
                        context,
                        title: 'DUYỆT',
                        icon: Icons.verified_user,
                        color: const Color(0xFF009688),
                        children: [
                          _buildModernTile(context, Icons.verified_user_outlined, 'Duyệt tài khoản', () => Navigator.pop(context, 1)),
                          _buildModernTile(context, Icons.link_outlined, 'Duyệt liên kết căn hộ', () => Navigator.pop(context, 4)),
                          _buildModernTile(context, Icons.calendar_today_outlined, 'Duyệt lịch tiện ích', () => Navigator.pop(context, 6)),
                          _buildModernTile(context, Icons.directions_car_outlined, 'Duyệt đăng ký xe', () => Navigator.pop(context, 11)),
                          _buildModernTile(context, Icons.store_outlined, 'Duyệt cửa hàng', () => Navigator.pop(context, 17)),
                        ],
                      ),
                      _buildModernSection(
                        context,
                        title: 'QUẢN LÝ',
                        icon: Icons.settings,
                        color: const Color(0xFF00796B),
                        children: [
                          _buildModernTile(context, Icons.event_available_outlined, 'Quản lý tiện ích', () => Navigator.pop(context, 5)),
                          _buildModernTile(context, Icons.feedback_outlined, 'Quản lý phản ánh', () => Navigator.pop(context, 7)),
                          _buildModernTile(context, Icons.confirmation_number_outlined, 'Quản lý gói vé xe', () => Navigator.pop(context, 12)),
                          _buildModernTile(context, Icons.credit_card_outlined, 'Quản lý vé xe', () => Navigator.pop(context, 13)),
                          _buildModernTile(context, Icons.receipt_long_outlined, 'Quản lý loại phí', () => Navigator.pop(context, 14)),
                          _buildModernTile(context, Icons.water_drop_outlined, 'Nhập chỉ số đồng hồ', () => Navigator.pop(context, 15)),
                          _buildModernTile(context, Icons.description_outlined, 'Quản lý hóa đơn', () => Navigator.pop(context, 16)),
                          _buildModernTile(context, Icons.add_card_outlined, 'Tạo hóa đơn tiện ích', () => Navigator.pop(context, 21)),
                          _buildModernTile(context, Icons.link, 'Lịch sử Blockchain', () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BlockchainHistoryPage(isAdminView: true),
                              ),
                            );
                          }),
                          _buildModernTile(context, Icons.store, 'Quản lý cửa hàng', () => Navigator.pop(context, 18)),
                        ],
                      ),
                      _buildModernSection(
                        context,
                        title: 'THỐNG KÊ',
                        icon: Icons.bar_chart,
                        color: const Color(0xFF5D4037),
                        children: [
                          _buildModernTile(context, Icons.bar_chart_outlined, 'Thống kê Marketplace', () => Navigator.pop(context, 19)),
                        ],
                      ),
                      _buildModernSection(
                        context,
                        title: 'GIAO TIẾP',
                        icon: Icons.forum,
                        color: const Color(0xFF1976D2),
                        children: [
                          _buildModernTile(context, Icons.support_agent, 'Yêu cầu Concierge', () => Navigator.pop(context, 20)),
                          _buildModernTile(context, Icons.support_agent_outlined, 'Hỗ trợ cư dân', () => Navigator.pop(context, 9)),
                          _buildModernTile(context, Icons.forum_outlined, 'Chat cộng đồng', () => Navigator.pop(context, 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      if (selected == 21) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminInvoiceGeneratorPage()),
        );
        setState(() {
          _currentPageIndex = 0;
          _navIndex = 0;
        });
      } else {
        setState(() {
          _currentPageIndex = selected;
          _navIndex = 4;
        });
      }
    }
  }

  Widget _buildModernSection(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModernTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 46), // Indent for alignment
              Icon(icon, color: const Color(0xFF009688), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BQL Chung cư'),
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            tooltip: Provider.of<ThemeProvider>(context).isDarkMode
                ? 'Chế độ sáng'
                : 'Chế độ tối',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = Provider.of<AuthState>(context, listen: false);
              await auth.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Đăng xuất',
          ),
          // Notification button
          IconButton(
            tooltip: 'Trung tâm thông báo',
            onPressed: () async {
              // Mở trực tiếp trang danh sách thông báo để nhìn rõ nội dung
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserNotificationsPage()),
              );
              if (mounted) {
                setState(() => _newNotificationCount = 0);
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                _notifLastSeenKeyManager,
                DateTime.now().toUtc().toIso8601String(),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (_newNotificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          _newNotificationCount > 9
                              ? '9+'
                              : '$_newNotificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          key: ValueKey<int>(_currentPageIndex),
          index: _currentPageIndex,
          children: _buildPages(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 62,
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          if (i == 4) {
            setState(() => _navIndex = 4);
            _openMore();
          } else {
            // Khi nhấn 1 trong 4 tab chính
            setState(() {
              _navIndex = i;
              _currentPageIndex = _primaryMap[i];
            });
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Người dùng'),
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Căn hộ'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Thông báo'),
          NavigationDestination(
              icon: Icon(Icons.menu_outlined), // [NÂNG CẤP] Đổi icon
              selectedIcon: Icon(Icons.menu),
              label: 'Khác'),
        ],
      ),
    );
  }
}