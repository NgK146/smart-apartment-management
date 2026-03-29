// Màn hình Giỏ hàng
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../services/marketplace_service.dart';
import 'my_orders_screen.dart';

class CartScreen extends StatefulWidget {
  final CartItem? initialItem;

  const CartScreen({super.key, this.initialItem});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final MarketplaceService _service = MarketplaceService();
  final List<CartItem> _items = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _items.add(widget.initialItem!);
    }
    // TODO: Load cart from local storage hoặc state management
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    setState(() {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int? get _storeId {
    if (_items.isEmpty) return null;
    return _items.first.product.storeId;
  }

  bool get _isSameStore {
    if (_items.isEmpty) return true;
    final firstStoreId = _items.first.product.storeId;
    return _items.every((item) => item.product.storeId == firstStoreId);
  }

  Future<void> _placeOrder() async {
    if (_items.isEmpty || !_isSameStore || _storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giỏ hàng trống hoặc có sản phẩm từ nhiều cửa hàng khác nhau')),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final orderItems = _items.map((item) => {
        'productId': item.product.id,
        'quantity': item.quantity,
      }).toList();

      await _service.createOrder(
        storeId: _storeId!,
        items: orderItems,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt hàng thành công!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Giỏ hàng trống',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Danh sách sản phẩm
                      ...List.generate(_items.length, (index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Ảnh sản phẩm
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.product.imageUrl != null &&
                                          item.product.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          item.product.imageUrl!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildPlaceholderImage(context),
                                        )
                                      : _buildPlaceholderImage(context),
                                ),
                                const SizedBox(width: 12),

                                // Thông tin sản phẩm
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.product.price.toStringAsFixed(0)} đ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Số lượng và xóa
                                Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          iconSize: 20,
                                          onPressed: () =>
                                              _updateQuantity(index, item.quantity - 1),
                                        ),
                                        Text('${item.quantity}'),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          iconSize: 20,
                                          onPressed: () =>
                                              _updateQuantity(index, item.quantity + 1),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${item.totalPrice.toStringAsFixed(0)} đ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Ghi chú
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú cho người bán (tùy chọn)',
                          border: OutlineInputBorder(),
                          hintText: 'Ví dụ: Giao hàng vào buổi sáng...',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                // Tổng tiền và nút đặt hàng
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tổng tiền:',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '${_totalAmount.toStringAsFixed(0)} đ',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: _isPlacingOrder
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Đặt hàng'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image,
          size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

