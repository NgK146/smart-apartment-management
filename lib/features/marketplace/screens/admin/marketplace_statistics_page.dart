// Màn hình Thống kê Marketplace (Admin)
import 'package:flutter/material.dart';
import '../../services/admin_store_service.dart';

class MarketplaceStatisticsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const MarketplaceStatisticsPage({super.key, this.onBack});

  @override
  State<MarketplaceStatisticsPage> createState() => _MarketplaceStatisticsPageState();
}

class _MarketplaceStatisticsPageState extends State<MarketplaceStatisticsPage> {
  final AdminStoreService _service = AdminStoreService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  // Màu chủ đạo (đồng bộ với các màn hình admin khác)
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _service.getStatistics();
      setState(() {
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
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // Header
          _buildHeader(),

          // Nội dung
          Expanded(
            child: _isLoading
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
                              onPressed: _loadStatistics,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _statistics == null
                        ? const Center(child: Text('Không có dữ liệu'))
                        : RefreshIndicator(
                            onRefresh: _loadStatistics,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thống kê tổng quan
                                  Text(
                                    'Tổng quan',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _StatCard(
                                        icon: Icons.store,
                                        title: 'Tổng số cửa hàng',
                                        value: _statistics!['totalStores']?.toString() ?? '0',
                                        subtitle: 'Đang hoạt động: ${_statistics!['activeStores'] ?? 0}',
                                        color: Colors.blue,
                                      ),
                                      _StatCard(
                                        icon: Icons.inventory_2,
                                        title: 'Tổng số sản phẩm',
                                        value: _statistics!['totalProducts']?.toString() ?? '0',
                                        subtitle: 'Đang bán: ${_statistics!['activeProducts'] ?? 0}',
                                        color: Colors.green,
                                      ),
                                      _StatCard(
                                        icon: Icons.receipt_long,
                                        title: 'Đơn hàng (tháng này)',
                                        value: _statistics!['ordersThisMonth']?.toString() ?? '0',
                                        subtitle: 'Đã hoàn thành: ${_statistics!['completedOrdersThisMonth'] ?? 0}',
                                        color: Colors.orange,
                                      ),
                                      _StatCard(
                                        icon: Icons.attach_money,
                                        title: 'Doanh thu (tháng này)',
                                        value: _formatCurrency(_statistics!['revenueThisMonth'] ?? 0),
                                        subtitle: 'Tổng giá trị đơn hàng',
                                        color: Colors.purple,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Thống kê chi tiết
                                  Text(
                                    'Chi tiết',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _StatRow(
                                            label: 'Cửa hàng chờ duyệt',
                                            value: _statistics!['pendingStores']?.toString() ?? '0',
                                            icon: Icons.pending_actions,
                                            color: Colors.orange,
                                          ),
                                          const Divider(height: 24),
                                          _StatRow(
                                            label: 'Cửa hàng đã khóa',
                                            value: _statistics!['inactiveStores']?.toString() ?? '0',
                                            icon: Icons.lock,
                                            color: Colors.red,
                                          ),
                                          const Divider(height: 24),
                                          _StatRow(
                                            label: 'Sản phẩm hết hàng',
                                            value: _statistics!['outOfStockProducts']?.toString() ?? '0',
                                            icon: Icons.inventory_2_outlined,
                                            color: Colors.grey,
                                          ),
                                          const Divider(height: 24),
                                          _StatRow(
                                            label: 'Đơn hàng đang xử lý',
                                            value: _statistics!['pendingOrders']?.toString() ?? '0',
                                            icon: Icons.hourglass_empty,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thống kê Marketplace',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tổng quan khu chợ nội khu',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 đ';
    final numValue = value is int ? value.toDouble() : (value as num).toDouble();
    if (numValue >= 1000000) {
      return '${(numValue / 1000000).toStringAsFixed(1)}M đ';
    } else if (numValue >= 1000) {
      return '${(numValue / 1000).toStringAsFixed(1)}K đ';
    }
    return '${numValue.toStringAsFixed(0)} đ';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 2,
        color: color.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

