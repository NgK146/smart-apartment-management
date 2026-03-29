// Màn hình Chi tiết Sản phẩm
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../services/marketplace_service.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final MarketplaceService _service = MarketplaceService();
  Product? _product;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final product = await _service.getProduct(widget.productId);
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addToCart() {
    if (_product == null || !_product!.isAvailable) return;

    // Lấy giỏ hàng từ CartScreen (sử dụng Provider hoặc Navigator với result)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          initialItem: CartItem(product: _product!, quantity: _quantity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
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
                        onPressed: _loadProduct,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _product == null
                  ? const Center(child: Text('Không tìm thấy sản phẩm'))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ảnh sản phẩm
                                _product!.imageUrl != null && _product!.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        _product!.imageUrl!,
                                        width: double.infinity,
                                        height: 300,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
                                      )
                                    : _buildPlaceholderImage(context),

                                // Thông tin sản phẩm
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _product!.name,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            '${_product!.price.toStringAsFixed(0)} đ',
                                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const Spacer(),
                                          if (!_product!.isAvailable)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.errorContainer,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Hết hàng',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onErrorContainer,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (_product!.description != null &&
                                          _product!.description!.isNotEmpty) ...[
                                        Text(
                                          'Mô tả',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _product!.description!,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      Row(
                                        children: [
                                          Text(
                                            'Loại: ',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Text(
                                            _product!.type == ProductType.service
                                                ? 'Dịch vụ'
                                                : 'Hàng hóa',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nút thêm vào giỏ hàng
                        if (_product!.isAvailable)
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
                                  // Chọn số lượng
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: _quantity > 1
                                            ? () => setState(() => _quantity--)
                                            : null,
                                      ),
                                      Text(
                                        '$_quantity',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => setState(() => _quantity++),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _addToCart,
                                    icon: const Icon(Icons.shopping_cart),
                                    label: Text(
                                      'Thêm vào giỏ hàng - ${(_product!.price * _quantity).toStringAsFixed(0)} đ',
                                    ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
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
      width: double.infinity,
      height: 300,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(Icons.image,
          size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

