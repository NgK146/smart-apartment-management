import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart'; // [THÊM] Cần cho nút Đăng xuất
import './manager_shell.dart' show managerShellKey;

import 'reports_service.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final _svc = ReportsService();
  Future<DashboardOverview>? _future;
  final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _future = _svc.overview();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _svc.overview();
    });
    await _future;
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
              : [const Color(0xFF009688), const Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Xin chào, Quản trị viên',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Tổng quan hoạt động',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // KHÔNG CÓ AppBar
      backgroundColor: Colors.grey.shade50,
      body: Column( // Bắt buộc dùng Column để đặt header ở trên cùng
        children: [
          // 1. HEADER
          _buildDashboardHeader(context),

          // 2. NỘI DUNG (Dùng Expanded bọc FutureBuilder)
          Expanded(
            child: FutureBuilder<DashboardOverview>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Lỗi tải dữ liệu: ${snapshot.error}', textAlign: TextAlign.center, style: GoogleFonts.inter()),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // [XÓA] Xóa tiêu đề "Tổng quan hoạt động" khỏi ListView vì nó đã có trong Header
                      // Text('Tổng quan hoạt động', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      // 2x2 Grid for Summary Cards with Animation
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.05, // Increased to prevent overflow
                        children: [
                          _AnimatedCard(
                            delay: 0,
                            child: SummaryCard(
                              icon: Icons.person_add_alt,
                              title: 'Tài khoản mới (tháng này)',
                              value: data.accounts.newThisMonth.toString(),
                              color: Colors.teal,
                              onTap: () => managerShellKey.currentState?.navigateToPage(1),
                            ),
                          ),
                          _AnimatedCard(
                            delay: 100,
                            child: SummaryCard(
                              icon: Icons.verified_user,
                              title: 'Tài khoản hoạt động (7 ngày)',
                              value: data.accounts.activeThisWeek.toString(),
                              color: Colors.blueGrey,
                              onTap: () => managerShellKey.currentState?.navigateToPage(2),
                            ),
                          ),
                          _AnimatedCard(
                            delay: 200,
                            child: SummaryCard(
                              icon: Icons.house,
                              title: 'Căn hộ đã có người ở',
                              value: '${data.apartments.occupied}/${data.apartments.total}',
                              color: Colors.indigo,
                              onTap: () => managerShellKey.currentState?.navigateToPage(3),
                            ),
                          ),
                          _AnimatedCard(
                            delay: 300,
                            child: SummaryCard(
                              icon: Icons.meeting_room_outlined,
                              title: 'Căn hộ còn trống',
                              value: data.apartments.vacant.toString(),
                              color: Colors.deepPurple,
                              onTap: () => managerShellKey.currentState?.navigateToPage(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: ListTile(
                          leading: Icon(Icons.report, color: Theme.of(context).colorScheme.onErrorContainer),
                          title: Text(
                            'Phản ánh chờ xử lý: ${data.complaints.pending}',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Quá hạn: ${data.complaints.overdue}',
                            style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FinanceCard(
                        collected: _currencyFormatter.format(data.finance.collectedThisMonth),
                        outstanding: _currencyFormatter.format(data.finance.outstandingThisMonth),
                        overdue: _currencyFormatter.format(data.finance.overdueAmount),
                        trend: data.finance.revenueTrend,
                      ),
                      const SizedBox(height: 16),
                       Container(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             colors: [Colors.white, Colors.grey.shade50],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           ),
                           borderRadius: BorderRadius.circular(20),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.06),
                               blurRadius: 16,
                               offset: const Offset(0, 4),
                             ),
                           ],
                         ),
                         child: Padding(
                           padding: const EdgeInsets.all(20),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Expanded(
                                     child: Text('Hộp hành động nhanh', 
                                       style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Icon(Icons.touch_app, color: const Color(0xFF009688), size: 18),
                                 ],
                               ),
                               const SizedBox(height: 16),
                                QuickActionTile(
                                  icon: Icons.warning_amber_rounded,
                                  title: 'Phản ánh trễ hạn',
                                  subtitle: 'Số phản ánh pending > 3 ngày',
                                  value: data.quickActions.overdueComplaints,
                                  onTap: data.quickActions.overdueComplaints > 0
                                      ? () => managerShellKey.currentState?.navigateToPage(7)
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                QuickActionTile(
                                  icon: Icons.person_add_alt_1,
                                  title: 'Yêu cầu duyệt tài khoản/ cư dân',
                                  subtitle: 'Cần xử lý để cư dân sử dụng ứng dụng',
                                  value: data.quickActions.pendingApprovals,
                                  onTap: data.quickActions.pendingApprovals > 0
                                      ? () => managerShellKey.currentState?.navigateToPage(4)
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                QuickActionTile(
                                  icon: Icons.chat_bubble_outline,
                                  title: 'Tin nhắn từ cư dân (chưa phản hồi)',
                                  subtitle: 'Ticket có phản hồi cuối từ cư dân',
                                  value: data.quickActions.unreadSupportTickets,
                                  onTap: data.quickActions.unreadSupportTickets > 0
                                      ? () => managerShellKey.currentState?.navigateToPage(20)
                                      : null,
                                ),
                             ],
                           ),
                         ),
                       ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;
                          final apartmentCard = Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tình trạng căn hộ', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 180,
                                    child: OccupancyPieChart(
                                      occupied: data.apartments.occupied,
                                      vacant: data.apartments.vacant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Đã có người ở: ${data.apartments.occupied}\nCòn trống: ${data.apartments.vacant}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final interactionCard = Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tương tác 7 ngày qua', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 180,
                                    child: InteractionLineChart(points: data.interaction),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: const [
                                      LegendDot(color: Colors.orange, label: 'Phản ánh mới'),
                                      SizedBox(width: 12),
                                      LegendDot(color: Colors.blue, label: 'Ticket hỗ trợ'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                apartmentCard,
                                const SizedBox(height: 12),
                                interactionCard,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: apartmentCard),
                              const SizedBox(width: 12),
                              Expanded(child: interactionCard),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14), // Reduced from 18
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Reduced from 12
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22), // Reduced from 24
            ),
            const SizedBox(height: 10), // Reduced
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10, // Reduced from 11
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6), // Reduced
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24, // Reduced from 28
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceCard extends StatelessWidget {
  final String collected;
  final String outstanding;
  final String overdue;
  final RevenueTrend trend;
  const FinanceCard({
    super.key,
    required this.collected,
    required this.outstanding,
    required this.overdue,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF009688), const Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009688).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tài chính tháng này',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tổng quan doanh thu',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: trend.currentMonth >= trend.previousMonth
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: trend.currentMonth >= trend.previousMonth
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend.currentMonth >= trend.previousMonth
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: trend.currentMonth >= trend.previousMonth
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend.currentMonth >= trend.previousMonth ? 'Tăng' : 'Giảm',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _FinanceStat(
                    icon: Icons.check_circle,
                    label: 'Đã thu',
                    value: collected,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FinanceStat(
                    icon: Icons.pending,
                    label: 'Còn nợ',
                    value: outstanding,
                    color: Colors.orangeAccent,
                  ),
                ),
               const SizedBox(width: 12),
                Expanded(
                  child: _FinanceStat(
                    icon: Icons.warning,
                    label: 'Quá hạn',
                    value: overdue,
                    color: Colors.redAccent,
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

class _FinanceStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _FinanceStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final VoidCallback? onTap;
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onTap != null ? const Color(0xFF009688).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF009688), Color(0xFF00695C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF009688).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: value > 0
                  ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)])
                  : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: value > 0
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              value.toString(),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }
    return content;
  }
}

class OccupancyPieChart extends StatelessWidget {
  final int occupied;
  final int vacant;
  const OccupancyPieChart({super.key, required this.occupied, required this.vacant});

  @override
  Widget build(BuildContext context) {
    final total = max(occupied + vacant, 1);
    return CustomPaint(
      painter: _PiePainter(
        occupied: occupied / total,
        vacant: vacant / total,
        colors: [Colors.teal, Colors.grey.shade400],
      ),
      child: Center(
        child: Text(
          total == 0 ? '0%' : '${(occupied / total * 100).toStringAsFixed(0)}% \nĐã ở',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final double occupied;
  final double vacant;
  final List<Color> colors;
  _PiePainter({required this.occupied, required this.vacant, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    double startAngle = -pi / 2;
    final occupiedSweep = 2 * pi * occupied;
    paint.color = colors[0];
    canvas.drawArc(rect, startAngle, occupiedSweep, true, paint);

    paint.color = colors[1];
    canvas.drawArc(rect, startAngle + occupiedSweep, 2 * pi - occupiedSweep, true, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class InteractionLineChart extends StatelessWidget {
  final List<InteractionPoint> points;
  const InteractionLineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InteractionChartPainter(points: points),
      child: Container(),
    );
  }
}

class _InteractionChartPainter extends CustomPainter {
  final List<InteractionPoint> points;
  _InteractionChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final complaints = points.map((e) => e.complaints).toList();
    final tickets = points.map((e) => e.tickets).toList();

    final maxValue = max(
      complaints.fold<int>(0, max),
      tickets.fold<int>(0, max),
    ).toDouble();

    final horizontalPadding = 24.0;
    final verticalPadding = 16.0;

    final chartWidth = size.width - horizontalPadding * 2;
    final chartHeight = size.height - verticalPadding * 2;

    final base = Offset(horizontalPadding, size.height - verticalPadding);

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke;

    final dashHeight = chartHeight / 4;
    for (var i = 0; i <= 4; i++) {
      final dy = base.dy - dashHeight * i;
      canvas.drawLine(Offset(horizontalPadding, dy), Offset(size.width - horizontalPadding, dy), gridPaint);
    }

    Offset pointFor(int index, int value) {
      final x = horizontalPadding + chartWidth * (index / max(points.length - 1, 1));
      final y = base.dy - (maxValue == 0 ? 0 : (value / maxValue) * chartHeight);
      return Offset(x, y);
    }

    void drawLine(List<int> values, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final pt = pointFor(i, values[i]);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, paint);
      for (var i = 0; i < values.length; i++) {
        final pt = pointFor(i, values[i]);
        canvas.drawCircle(pt, 3, Paint()..color = color);
      }
    }

    drawLine(complaints, Colors.orange);
    drawLine(tickets, Colors.blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RevenueBarChart extends StatelessWidget {
  final double current;
  final double previous;
  const RevenueBarChart({super.key, required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxValue = max(current, previous);
        final barHeight = max(constraints.maxHeight - 40, 40.0);
        double scaled(double value) {
          if (maxValue == 0) return 0;
          final raw = (value / maxValue) * barHeight;
          return value > 0 ? max(raw, 8) : 0;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Bar(
              color: Colors.blue.shade400,
              value: current,
              height: scaled(current),
              label: 'Tháng này',
            ),
            const SizedBox(width: 24),
            _Bar(
              color: Colors.grey.shade500,
              value: previous,
              height: scaled(previous),
              label: 'Tháng trước',
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final double value;
  final double height;
  final String label;
  const _Bar({
    required this.color,
    required this.value,
    required this.height,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compact(locale: 'vi_VN');
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatter.format(value),
            style: const TextStyle(fontSize: 11),
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// Animation helper widget for staggered card entry
class _AnimatedCard extends StatelessWidget {
  final int delay;
  final Widget child;

  const _AnimatedCard({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

extension _ColorShade on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}