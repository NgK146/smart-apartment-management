import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui/snackbar.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  // DANH SÁCH LIÊN HỆ
  final items = const [
    ('Lễ tân Tòa A', '0900000001', Color(0xFF29B6F6)), // Xanh dương
    ('Bảo vệ (Cổng chính)', '0900000002', Color(0xFF66BB6A)), // Xanh lá
    ('Hỗ trợ Kỹ thuật', '0900000003', Color(0xFFFFA726)), // Cam
    ('Phòng Kế toán', '0900000004', Color(0xFFAB47BC)), // Tím
    ('Ban quản lý (Trực)', '0900000005', Color(0xFFEF5350)), // Đỏ
  ];

  // Hàm chọn Icon tự động
  IconData _getIconForContact(String name) {
    final n = name.toLowerCase();
    if (n.contains('lễ tân')) return Icons.room_service_outlined;
    if (n.contains('bảo vệ')) return Icons.shield_outlined;
    if (n.contains('kỹ thuật')) return Icons.build_outlined;
    if (n.contains('kế toán')) return Icons.receipt_long_outlined;
    if (n.contains('quản lý')) return Icons.admin_panel_settings_outlined;
    return Icons.phone_outlined; // Mặc định
  }

  // Hàm thực hiện cuộc gọi
  Future<void> _launchCall(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Hiển thị lỗi nếu không gọi được
      showSnack(context, 'Không thể thực hiện cuộc gọi', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Màu chủ đạo (Teal)
    final Color primaryColor = const Color(0xFF009688);
    final Color backgroundColor = const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Danh bạ khẩn cấp'),
        // Đồng bộ AppBar với Gradient
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent, // Quan trọng
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Dự phòng nếu trang này là trang đầu tiên
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            }
          },
          tooltip: 'Quay lại',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final (name, phone, color) = items[i];
          final iconData = _getIconForContact(name);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  // Icon
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),

                  // Tên và SĐT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Nút Gọi
                  IconButton.filled(
                    icon: const Icon(Icons.call_rounded),
                    onPressed: () => _launchCall(context, phone),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green, // Nút gọi màu xanh
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'Gọi $name',
                  )
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              break;
            case 1:
              Navigator.of(context).pushReplacementNamed('/notifications');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/complaints');
              break;
            case 3:
              Navigator.of(context).pushReplacementNamed('/invoices');
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/amenities');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Thông báo'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Phản ánh'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Hoá đơn'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: 'Tiện ích'),
        ],
      ),
    );
  }
}