import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../../core/ui/page_transitions.dart';
import 'amenities_service.dart';
import 'amenity_model.dart';
import 'amenity_booking_page.dart';

class AmenitiesPage extends StatefulWidget {
  const AmenitiesPage({super.key});

  @override
  State<AmenitiesPage> createState() => _AmenitiesPageState();
}

class _AmenitiesPageState extends State<AmenitiesPage> {
  final _svc = AmenitiesService();
  List<Amenity> _items = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = [];

  // Màu chủ đạo
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search - reload sau 500ms khi user ngừng gõ
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == _searchController.text) {
        _loadData();
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _svc.getCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (e) {
      // Nếu lỗi, dùng danh sách mặc định
      if (mounted) {
        setState(() => _categories = AmenitiesService.defaultCategories);
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final searchText = _searchController.text.trim();
      final data = await _svc.list(
        search: searchText.isEmpty ? null : searchText,
        category: _selectedCategory,
      );
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải tiện ích: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Hàm chọn Icon tự động dựa theo tên tiện ích
  IconData _getIconForAmenity(String name) {
    final n = name.toLowerCase();
    if (n.contains('bơi') || n.contains('pool')) return Icons.pool;
    if (n.contains('gym') || n.contains('thể hình')) return Icons.fitness_center;
    if (n.contains('bbq') || n.contains('nướng')) return Icons.outdoor_grill;
    if (n.contains('tennis') || n.contains('bóng')) return Icons.sports_tennis;
    if (n.contains('xe') || n.contains('park')) return Icons.local_parking;
    if (n.contains('hội trường') || n.contains('hall')) return Icons.meeting_room;
    if (n.contains('chơi') || n.contains('kid')) return Icons.child_care;
    return Icons.deck; // Icon mặc định (cái ghế thư giãn)
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Header
          _buildHeader(),

          // 2. Category Filter
          if (_categories.isNotEmpty) _buildCategoryFilter(),

          // 3. Danh sách tiện ích
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: theme.colorScheme.primary,
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
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      return _buildAmenityCard(_items[index]);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 45, 16, 45),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                ? [
                    const Color(0xFF1A237E),
                    const Color(0xFF4A148C),
                    const Color(0xFF006064),
                  ]
                : [
                    const Color(0xFF0091EA),
                    const Color(0xFF00B8D4),
                    const Color(0xFF00BFA5),
                  ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Quay lại',
                ),
                const SizedBox(height: 12),
                Text(
                  'Dịch vụ cư dân', 
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tiện ích chung cư', 
                  style: GoogleFonts.montserrat(
                    color: Colors.white, 
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_items.length} dịch vụ đang hoạt động', 
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Search Bar
        Positioned(
          bottom: -22,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiện ích...',
                hintStyle: GoogleFonts.inter(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityCard(Amenity amenity) {
    final iconData = _getIconForAmenity(amenity.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.sharedAxisHorizontal(
                page: AmenityBookingPage(amenity: amenity),
              ),
            ).then((ok) { if (ok == true) _loadData(); });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box Lớn
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                              begin: Alignment.topLeft, end: Alignment.bottomRight
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ]
                      ),
                      child: Icon(iconData, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),

                    // Thông tin
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            amenity.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            amenity.description ?? 'Không có mô tả',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Footer: trạng thái + nút đặt lịch (tự xuống dòng khi thiếu chỗ)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Đang hoạt động', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: 160,
                            maxWidth: constraints.maxWidth > 200 ? 200 : constraints.maxWidth,
                          ),
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AmenityBookingPage(amenity: amenity)))
                                  .then((ok) { if (ok == true) _loadData(); });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: const Text('Đặt lịch ngay'),
                          ),
                        ),
                      ],
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 10, bottom: 5),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(null, 'Tất cả'),
          ..._categories.map((cat) => _buildCategoryChip(cat, cat)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategory = category;
            });
            _loadData();
          }
        },
        selectedColor: _primaryColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: isSelected ? _primaryColor : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? _primaryColor : Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.weekend_outlined, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory != null
                ? 'Không có tiện ích nào trong danh mục này'
                : 'Chưa có tiện ích nào',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedCategory = null);
                _loadData();
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ],
      ),
    );
  }
}