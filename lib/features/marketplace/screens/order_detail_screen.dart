// Màn hình Chi tiết Đơn hàng
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/marketplace_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final MarketplaceService _service = MarketplaceService();
  Order? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await _service.getOrder(widget.orderId);
      setState(() {
        _order = order;
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
        title: const Text('Chi tiết đơn hàng'),
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
                        onPressed: _loadOrder,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _order == null
                  ? const Center(child: Text('Không tìm thấy đơn hàng'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thông tin đơn hàng
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Đơn hàng #${_order!.id}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      _buildStatusChip(context, _order!.status),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (_order!.storeName != null) ...[
                                    _buildInfoRow(
                                      context,
                                      icon: Icons.store,
                                      label: 'Cửa hàng',
                                      value: _order!.storeName!,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_order!.createdAt != null) ...[
                                    _buildInfoRow(
                                      context,
                                      icon: Icons.calendar_today,
                                      label: 'Ngày đặt',
                                      value: '${_order!.createdAt!.day}/${_order!.createdAt!.month}/${_order!.createdAt!.year} ${_order!.createdAt!.hour}:${_order!.createdAt!.minute.toString().padLeft(2, '0')}',
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildInfoRow(
                                    context,
                                    icon: Icons.attach_money,
                                    label: 'Tổng tiền',
                                    value: '${_order!.totalAmount.toStringAsFixed(0)} đ',
                                    valueStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Ghi chú:',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_order!.notes!),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Chi tiết sản phẩm
                          Text(
                            'Sản phẩm',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (_order!.orderDetails != null && _order!.orderDetails!.isNotEmpty)
                            ..._order!.orderDetails!.map((detail) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: detail.product?.imageUrl != null &&
                                          detail.product!.imageUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            detail.product!.imageUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 56,
                                              height: 56,
                                              color: Theme.of(context).colorScheme.surfaceVariant,
                                              child: Icon(Icons.image,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.image,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                        ),
                                  title: Text(detail.product?.name ?? 'Sản phẩm #${detail.productId}'),
                                  subtitle: Text('${detail.priceAtPurchase.toStringAsFixed(0)} đ'),
                                  trailing: Text(
                                    'x${detail.quantity}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              );
                            })
                          else
                            const Text('Không có chi tiết sản phẩm'),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, OrderStatus status) {
    Color statusColor;
    switch (status) {
      case OrderStatus.pending:
        statusColor = Colors.orange;
        break;
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        break;
      case OrderStatus.delivering:
        statusColor = Colors.purple;
        break;
      case OrderStatus.completed:
        statusColor = Colors.green;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _order!.statusText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

