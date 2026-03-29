// Màn hình Xét duyệt Cửa hàng (Admin)
import 'package:flutter/material.dart';
import '../../models/store_model.dart';
import '../../services/admin_store_service.dart';
import '../../../../core/ui/snackbar.dart';

class PendingStoresPage extends StatefulWidget {
  const PendingStoresPage({super.key});

  @override
  State<PendingStoresPage> createState() => _PendingStoresPageState();
}

class _PendingStoresPageState extends State<PendingStoresPage> {
  final AdminStoreService _service = AdminStoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Store> _stores = [];
  List<Store> _filteredStores = [];
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
      final stores = await _service.getPendingStores();
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

  Future<void> _approveStore(Store store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận duyệt'),
        content: Text('Bạn có chắc chắn muốn duyệt cửa hàng "${store.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.approveStore(store.id);
        if (mounted) {
          showSnack(context, 'Đã duyệt cửa hàng "${store.name}"');
          _loadStores();
        }
      } catch (e) {
        if (mounted) {
          showSnack(context, 'Lỗi duyệt cửa hàng: $e', error: true);
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
                                  'Không có cửa hàng nào chờ duyệt',
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
                                  onApprove: () => _approveStore(store),
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
                          'Xét duyệt Cửa hàng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_stores.length} cửa hàng chờ duyệt',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onApprove;

  const _StoreCard({required this.store, required this.onApprove});

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
                      Text(
                        store.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                      if (store.description != null && store.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          store.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
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
                OutlinedButton(
                  onPressed: () {
                    // Xem chi tiết (có thể mở dialog hoặc màn hình mới)
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(store.name),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (store.phone != null)
                                Text('SĐT: ${store.phone}'),
                              if (store.description != null) ...[
                                const SizedBox(height: 8),
                                Text('Mô tả: ${store.description}'),
                              ],
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Xem chi tiết'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                  ),
                  child: const Text('Duyệt'),
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

