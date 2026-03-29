// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_provider.dart';
import '../resident/link_apartment_page.dart';
import '../visitor/visitor_access_page.dart';
import '../concierge/concierge_page.dart';
import '../payment/digital_payment_page.dart';
import '../events/community_events_page.dart';
import '../notifications/notifications_service.dart';
import '../complaints/complaints_service.dart';
import '../billing/invoices_service.dart';
import '../amenities/amenities_service.dart';
import '../suggestions/suggestions_page.dart';

class HomePage extends StatefulWidget {
  final Function(int) onNavigateToTab;
  const HomePage({super.key, required this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _notificationCount;
  int? _complaintsInProgress;
  int? _unpaidInvoices;
  int? _upcomingAmenities;
  bool _countsLoading = false;
  String? _countsError;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _countsLoading = true;
      _countsError = null;
    });
    try {
      final results = await Future.wait<int>([
        NotificationsService().countActive(),
        ComplaintsService().countMyComplaints(status: 'InProgress'),
        InvoicesService().countMyInvoices(status: 'Unpaid'),
        AmenitiesService().countMyBookings(status: 'Approved', upcomingOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _notificationCount = results[0];
        _complaintsInProgress = results[1];
        _unpaidInvoices = results[2];
        _upcomingAmenities = results[3];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _countsError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _countsLoading = false);
      }
    }
  }

  Future<void> _handleRefresh(BuildContext context) async {
    await context.read<AuthState>().loadProfile();
    await _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final hasApartment =
        auth.apartmentCode != null && auth.apartmentCode!.isNotEmpty && auth.apartmentCode != '0';
    final isVerified = auth.isResidentVerified;

    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WelcomeHeader(auth: auth),
          const SizedBox(height: 16),
          if (!hasApartment)
            _LinkApartmentCard(onLinked: () {
              context.read<AuthState>().loadProfile();
            })
          else if (hasApartment && !isVerified)
            const _PendingApprovalCard(),
          if (_countsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Không thể tải dữ liệu dashboard: $_countsError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _QuickDashboard(
            onNavigateToTab: widget.onNavigateToTab,
            loading: _countsLoading,
            notificationCount: _notificationCount,
            complaintsInProgress: _complaintsInProgress,
            unpaidInvoices: _unpaidInvoices,
            upcomingAmenities: _upcomingAmenities,
            hasError: _countsError != null,
          ),
          const SizedBox(height: 24),
          _ActivitySuggestionsCard(),
          const SizedBox(height: 24),
          _OtherServices(),
        ],
      ),
    );
  }
}

// === WIDGET HEADER CHÀO MỪNG ===
class _WelcomeHeader extends StatelessWidget {
  final AuthState auth;
  const _WelcomeHeader({required this.auth});

  @override
  Widget build(BuildContext context) {
    final hasApartment =
        auth.apartmentCode != null && auth.apartmentCode!.isNotEmpty && auth.apartmentCode != '0';
    final isVerified = auth.isResidentVerified;

    String apartmentStatus;
    if (!hasApartment) {
      apartmentStatus = 'Chưa liên kết căn hộ';
    } else if (!isVerified) {
      apartmentStatus = 'Căn hộ: ${auth.apartmentCode} (Chờ duyệt)';
    } else {
      apartmentStatus = 'Căn hộ: ${auth.apartmentCode}';
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            auth.fullName?.substring(0, 1) ?? auth.username?.substring(0, 1) ?? '?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chào mừng,',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              Text(
                auth.fullName ?? auth.username ?? 'Cư dân',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                apartmentStatus,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === WIDGET CTA: LIÊN KẾT CĂN HỘ ===
class _LinkApartmentCard extends StatelessWidget {
  final VoidCallback onLinked;
  const _LinkApartmentCard({required this.onLinked});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          Icons.link_rounded,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 28,
        ),
        title: Text(
          'Liên kết căn hộ của bạn',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          'Nhấn để bắt đầu liên kết ngay.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LinkApartmentPage()));
          if (result == true) {
            onLinked();
          }
        },
      ),
    );
  }
}

// === WIDGET INFO: CHỜ DUYỆT ===
class _PendingApprovalCard extends StatelessWidget {
  const _PendingApprovalCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
          size: 28,
        ),
        title: Text(
          'Đang chờ xác thực',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        subtitle: Text(
          'Ban quản lý đang xem xét thông tin căn hộ của bạn.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

// === WIDGET DASHBOARD CHÍNH ===
class _QuickDashboard extends StatelessWidget {
  final Function(int) onNavigateToTab;
  final bool loading;
  final bool hasError;
  final int? notificationCount;
  final int? complaintsInProgress;
  final int? unpaidInvoices;
  final int? upcomingAmenities;

  const _QuickDashboard({
    required this.onNavigateToTab,
    required this.loading,
    required this.hasError,
    required this.notificationCount,
    required this.complaintsInProgress,
    required this.unpaidInvoices,
    required this.upcomingAmenities,
  });

  String _buildSubtitle(int? count, String label, String emptyText) {
    if (loading) return 'Đang tải...';
    if (hasError) return 'Không tải được';
    if (count == null || count == 0) return emptyText;
    return '$count $label';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true, // Quan trọng: để GridView nằm trong ListView
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _DashboardCard(
          title: 'Thông báo',
          subtitle: _buildSubtitle(notificationCount, 'thông báo', 'Không có thông báo'),
          icon: Icons.campaign_outlined,
          color: Colors.blue,
          onTap: () => onNavigateToTab(1), // Nhấn để mở tab Thông báo
        ),
        _DashboardCard(
          title: 'Phản ánh',
          subtitle: _buildSubtitle(complaintsInProgress, 'đang xử lý', 'Không có phản ánh'),
          icon: Icons.report_outlined,
          color: Colors.orange,
          onTap: () => onNavigateToTab(2), // Nhấn để mở tab Phản ánh
        ),
        _DashboardCard(
          title: 'Hoá đơn',
          subtitle: _buildSubtitle(unpaidInvoices, 'chờ thanh toán', 'Không có hoá đơn cần trả'),
          icon: Icons.receipt_long_outlined,
          color: Colors.green,
          onTap: () => onNavigateToTab(3), // Nhấn để mở tab Hoá đơn
        ),
        _DashboardCard(
          title: 'Tiện ích',
          subtitle: _buildSubtitle(upcomingAmenities, 'lịch sắp tới', 'Chưa có lịch sắp tới'),
          icon: Icons.event_available_outlined,
          color: Colors.purple,
          onTap: () => onNavigateToTab(4), // Nhấn để mở tab Tiện ích
        ),
      ],
    );
  }
}

// Thẻ con cho QuickDashboard
class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
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
}

// === WIDGET DỊCH VỤ KHÁC ===
class _OtherServices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dịch vụ khác',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Sử dụng Card cho giao diện hiện đại
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildServiceTile(context,
                  icon: Icons.qr_code_scanner,
                  title: 'Quản lý khách',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VisitorAccessPage()),
                  )),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.room_service,
                  title: 'Dịch vụ Concierge',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConciergePage()),
                  )),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.account_balance_wallet,
                  title: 'Thanh toán số',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DigitalPaymentPage()),
                  )),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.event,
                  title: 'Sự kiện cộng đồng',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityEventsPage()),
                  )),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.directions_car_outlined,
                  title: 'Xe & Thẻ ra vào',
                  route: '/vehicles'),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.apartment_outlined,
                  title: 'Căn hộ của tôi',
                  route: '/apartments'),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.support_agent_outlined,
                  title: 'Liên hệ Ban Quản lý',
                  route: '/contacts'),
              const Divider(height: 1),
              _buildServiceTile(context,
                  icon: Icons.store_outlined,
                  title: 'Khu Chợ Nội Khu',
                  route: '/marketplace'),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildServiceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? route,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap ?? (route != null ? () => Navigator.of(context).pushNamed(route) : null),
    );
  }
}

// === WIDGET GỢI Ý HOẠT ĐỘNG ===
class _ActivitySuggestionsCard extends StatelessWidget {
  const _ActivitySuggestionsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SuggestionsPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gợi ý hoạt động',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Xem các hoạt động phù hợp với bạn hôm nay',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}