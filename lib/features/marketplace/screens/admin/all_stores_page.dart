// Màn hình Quản lý Cửa hàng (Admin)
import 'package:flutter/material.dart';
import '../../models/store_model.dart';
import '../../services/admin_store_service.dart';
import '../../../../core/ui/snackbar.dart';

class AllStoresPage extends StatefulWidget {
  const AllStoresPage({super.key});

  @override
  State<AllStoresPage> createState() => _AllStoresPageState();
}

class _AllStoresPageState extends State<AllStoresPage> {
  final AdminStoreService _service = AdminStoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Store> _stores = [];
  List<Store> _filteredStores = [];
  bool? _filterActive; // null = tất cả, true = chỉ active, false = chỉ inactive
  bool _isLoading = true;
  String? _error;

  // Màu chủ đạo (đồng bộ với các màn hình admin khác)
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

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stores = await _service.getAllStores(isActive: _filterActive);
      setState(() {
        _stores = stores;
        _filteredStores = stores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterStores() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredStores = _stores;
      });
    } else {
      setState(() {
        _filteredStores = _stores.where((store) {
          return store.name.toLowerCase().contains(query) ||
              (store.phone?.toLowerCase().contains(query) ?? false) ||
              (store.description?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  Future<void> _toggleStoreActive(Store store) async {
    final action = store.isActive ? 'khóa' : 'mở khóa';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Text('Bạn có chắc chắn muốn $action cửa hàng "${store.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.toggleStoreActive(store.id);
        if (mounted) {
          showSnack(context, 'Đã $action cửa hàng "${store.name}"');
          _loadStores();
        }
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Lỗi: $e', error: true);
        }
      }
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

          // Danh sách cửa hàng
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
                              onPressed: _loadStores,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _filteredStores.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_outlined,
                                    size: 64, color: Theme.of(context).colorScheme.outline),
                                const SizedBox(height: 16),
                                Text(
                                  'Không có cửa hàng nào',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStores,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredStores.length,
                              itemBuilder: (context, index) {
                                final store = _filteredStores[index];
                                return _StoreCard(
                                  store: store,
                                  onToggleActive: () => _toggleStoreActive(store),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quản lý Cửa hàng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_stores.length} cửa hàng',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Thanh tìm kiếm
              TextField(
                controller: _searchController,
                onChanged: (_) => _filterStores(),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cửa hàng...',
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            _filterStores();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Colors.white70),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              // Bộ lọc trạng thái
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả', _filterActive == null, () {
                      setState(() {
                        _filterActive = null;
                      });
                      _loadStores();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Đang hoạt động', _filterActive == true, () {
                      setState(() {
                        _filterActive = true;
                      });
                      _loadStores();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Đã khóa', _filterActive == false, () {
                      setState(() {
                        _filterActive = false;
                      });
                      _loadStores();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.white,
      checkmarkColor: _primaryColor,
      labelStyle: TextStyle(
        color: selected ? _primaryColor : Colors.white70,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onToggleActive;

  const _StoreCard({required this.store, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              store.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          // Badge trạng thái
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: store.isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              store.isActive ? 'Đang hoạt động' : 'Đã khóa',
                              style: TextStyle(
                                color: store.isActive ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (store.phone != null && store.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
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
                        ),
                      ],
                      if (store.averageRating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
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
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(store.isActive ? Icons.lock_outline : Icons.lock_open_outlined),
                  label: Text(store.isActive ? 'Khóa' : 'Mở khóa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: store.isActive ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
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
      child: Icon(Icons.store,
          color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }
}

