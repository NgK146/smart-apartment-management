// Màn hình Quản lý Cửa hàng (Dashboard cho người bán)
import 'package:flutter/material.dart';
import '../models/store_model.dart';
import '../services/my_store_service.dart';
import 'seller_product_screen.dart';
import 'seller_category_screen.dart';
import 'seller_order_screen.dart';
import 'seller_review_screen.dart';
import 'seller_profile_screen.dart';

class StoreDashboardScreen extends StatefulWidget {
  const StoreDashboardScreen({super.key});

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  final MyStoreService _service = MyStoreService();
  Store? _store;
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final store = await _service.getMyStore();
      Map<String, dynamic>? stats;
      try {
        stats = await _service.getStatistics();
      } catch (_) {
        // Statistics có thể không có
      }

      setState(() {
        _store = store;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Cửa hàng'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Lỗi: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _store == null
                  ? const Center(child: Text('Không tìm thấy cửa hàng'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header chào mừng
                            Card(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.store,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Chào mừng!',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                          ),
                                          Text(
                                            _store!.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Thống kê nhanh
                            if (_statistics != null) ...[
                              Text(
                                'Thống kê',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: 1.5,
                                children: [
                                  _StatCard(
                                    icon: Icons.receipt_long,
                                    label: 'Đơn hàng mới',
                                    value: _statistics!['pendingOrders']?.toString() ?? '0',
                                    color: Colors.orange,
                                  ),
                                  _StatCard(
                                    icon: Icons.attach_money,
                                    label: 'Doanh thu tháng',
                                    value: _statistics!['monthlyRevenue'] != null
                                        ? '${(_statistics!['monthlyRevenue'] as num).toStringAsFixed(0)} đ'
                                        : '0 đ',
                                    color: Colors.green,
                                  ),
                                  _StatCard(
                                    icon: Icons.inventory_2,
                                    label: 'Sản phẩm',
                                    value: _statistics!['totalProducts']?.toString() ?? '0',
                                    color: Colors.blue,
                                  ),
                                  _StatCard(
                                    icon: Icons.star,
                                    label: 'Đánh giá TB',
                                    value: _statistics!['averageRating'] != null
                                        ? (_statistics!['averageRating'] as num).toStringAsFixed(1)
                                        : '0.0',
                                    color: Colors.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Menu quản lý
                            Text(
                              'Quản lý',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildMenuTile(
                              context,
                              icon: Icons.receipt_long_outlined,
                              title: 'Đơn hàng',
                              subtitle: 'Quản lý đơn hàng đến cửa hàng',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SellerOrderScreen()),
                                );
                              },
                            ),
                            _buildMenuTile(
                              context,
                              icon: Icons.inventory_2_outlined,
                              title: 'Sản phẩm',
                              subtitle: 'Thêm, sửa, xóa sản phẩm',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SellerProductScreen()),
                                );
                              },
                            ),
                            _buildMenuTile(
                              context,
                              icon: Icons.category_outlined,
                              title: 'Danh mục',
                              subtitle: 'Quản lý danh mục sản phẩm',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SellerCategoryScreen()),
                                );
                              },
                            ),
                            _buildMenuTile(
                              context,
                              icon: Icons.star_outline,
                              title: 'Đánh giá',
                              subtitle: 'Xem đánh giá từ khách hàng',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SellerReviewScreen()),
                                );
                              },
                            ),
                            _buildMenuTile(
                              context,
                              icon: Icons.settings_outlined,
                              title: 'Tùy chỉnh Cửa hàng',
                              subtitle: 'Sửa logo, ảnh bìa, mô tả...',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SellerProfileScreen(store: _store!),
                                  ),
                                ).then((_) => _loadData());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

