// Màn hình Trang Cửa hàng (Store Front) - Xem cửa hàng và sản phẩm
import 'package:flutter/material.dart';
import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/product_category_model.dart';
import '../services/marketplace_service.dart';
import 'product_detail_screen.dart';

class StoreFrontScreen extends StatefulWidget {
  final int storeId;

  const StoreFrontScreen({super.key, required this.storeId});

  @override
  State<StoreFrontScreen> createState() => _StoreFrontScreenState();
}

class _StoreFrontScreenState extends State<StoreFrontScreen> {
  final MarketplaceService _service = MarketplaceService();
  Store? _store;
  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  int? _selectedCategoryId;
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
      final store = await _service.getStore(widget.storeId);
      final products = await _service.getStoreProducts(widget.storeId);
      // Lấy danh mục từ sản phẩm (hoặc có thể có API riêng)
      final categoriesMap = <int, ProductCategory>{};
      for (var product in products) {
        if (!categoriesMap.containsKey(product.productCategoryId)) {
          categoriesMap[product.productCategoryId] = ProductCategory(
            id: product.productCategoryId,
            name: product.categoryName ?? 'Khác',
            storeId: widget.storeId,
          );
        }
      }
      final categories = categoriesMap.values.toList();

      setState(() {
        _store = store;
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterByCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  List<Product> get _filteredProducts {
    if (_selectedCategoryId == null) return _products;
    return _products.where((p) => p.productCategoryId == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_store?.name ?? 'Cửa hàng'),
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
                      child: CustomScrollView(
                        slivers: [
                          // Header cửa hàng
                          SliverToBoxAdapter(
                            child: _StoreHeader(store: _store!),
                          ),

                          // Danh mục
                          if (_categories.isNotEmpty)
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 50,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _categories.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          label: const Text('Tất cả'),
                                          selected: _selectedCategoryId == null,
                                          onSelected: (_) => _filterByCategory(null),
                                        ),
                                      );
                                    }
                                    final category = _categories[index - 1];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(category.name),
                                        selected: _selectedCategoryId == category.id,
                                        onSelected: (_) => _filterByCategory(category.id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          // Danh sách sản phẩm
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: _filteredProducts.isEmpty
                                ? SliverToBoxAdapter(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          children: [
                                            Icon(Icons.inventory_2_outlined,
                                                size: 64,
                                                color: Theme.of(context).colorScheme.outline),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Chưa có sản phẩm nào',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                      color:
                                                          Theme.of(context).colorScheme.outline),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.75,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final product = _filteredProducts[index];
                                        return _ProductCard(
                                          product: product,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductDetailScreen(productId: product.id),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      childCount: _filteredProducts.length,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final Store store;

  const _StoreHeader({required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ảnh bìa
        if (store.coverImageUrl != null && store.coverImageUrl!.isNotEmpty)
          Image.network(
            store.coverImageUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.store,
                  size: 64, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          )
        else
          Container(
            height: 200,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.store,
                size: 64, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),

        // Thông tin cửa hàng
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: store.logoUrl != null && store.logoUrl!.isNotEmpty
                    ? Image.network(
                        store.logoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderLogo(context),
                      )
                    : _buildPlaceholderLogo(context),
              ),
              const SizedBox(width: 16),

              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (store.description != null && store.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        store.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (store.averageRating != null) ...[
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            store.averageRating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (store.totalReviews != null && store.totalReviews! > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${store.totalReviews})',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ],
                        if (store.phone != null && store.phone!.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.phone,
                              size: 16, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            store.phone!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderLogo(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.store,
          color: Theme.of(context).colorScheme.onSecondaryContainer),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh sản phẩm
            Expanded(
              flex: 3,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
                    )
                  : _buildPlaceholderImage(context),
            ),

            // Thông tin sản phẩm
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${product.price.toStringAsFixed(0)} đ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (!product.isAvailable)
                      Text(
                        'Hết hàng',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(Icons.image,
          size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

