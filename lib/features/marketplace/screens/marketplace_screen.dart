// Màn hình Chợ (Marketplace) - Danh sách các cửa hàng
import
'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../core/ui/page_transitions.dart';
import '../models/store_model.dart';
import '../services/marketplace_service.dart';
import 'store_front_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceService _service = MarketplaceService();
  final TextEditingController _searchController = TextEditingController();
  List<Store> _stores = [];
  bool _isLoading = true;
  String? _error;

  // Màu chủ đạo (đồng bộ với ComplaintsPage)
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStores({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stores = await _service.getStores(search: search);
      setState(() {
        _stores = stores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    _loadStores(search: query.isEmpty ? null : query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // 1. Header với floating search
          _buildHeader(),

          // 2. Danh sách cửa hàng
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
                              onPressed: () => _loadStores(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _stores.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_outlined,
                                    size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text(
                                  'Chưa có cửa hàng nào',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadStores(),
                            color: _primaryColor,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Responsive: số cột thay đổi theo kích thước màn hình
                                final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                                final isTablet = ResponsiveBreakpoints.of(context).isTablet;
                                final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
                                
                                return MasonryGridView.count(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
                                  itemCount: _stores.length,
                                  itemBuilder: (context, index) {
                                    final store = _stores[index];
                                    return _StoreCard(
                                      store: store,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageTransitions.sharedAxisHorizontal(
                                            page: StoreFrontScreen(storeId: store.id),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nút quay lại
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  }
                },
                tooltip: 'Quay lại',
              ),
              const SizedBox(height: 8),
              const Text('Dịch vụ cư dân', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Khu Chợ Nội Khu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('${_stores.length} cửa hàng', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        // Floating Search Bar
        Positioned(
          bottom: -25,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Tìm kiếm cửa hàng...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearch,
                  onSubmitted: (_) => _onSearch(_searchController.text),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo cửa hàng
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: store.logoUrl != null && store.logoUrl!.isNotEmpty
                        ? Image.network(
                            store.logoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderLogo(context),
                          )
                        : _buildPlaceholderLogo(context),
                  ),
                  const SizedBox(width: 16),

                  // Thông tin cửa hàng
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (store.averageRating != null) ...[
                              Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                store.averageRating!.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall,
                              ),
                              if (store.totalReviews != null && store.totalReviews! > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${store.totalReviews})',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12),
                            ],
                            if (store.phone != null && store.phone!.isNotEmpty) ...[
                              Icon(Icons.phone,
                                  size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                store.phone!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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
              if (store.description != null && store.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  store.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderLogo(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.store,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

