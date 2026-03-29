import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';
import '../amenities/amenities_service.dart';
import '../amenities/amenity_model.dart';
import '../../core/ui/snackbar.dart';
import '../../core/api_client.dart';
import 'dart:async';

class AmenitiesAdminPage extends StatefulWidget {
  const AmenitiesAdminPage({super.key});
  @override
  State<AmenitiesAdminPage> createState() => _AmenitiesAdminPageState();
}

class _AmenitiesAdminPageState extends State<AmenitiesAdminPage> {
  final _svc = AmenitiesService();
  final _search = TextEditingController();
  List<Amenity> _items = [];
  bool _loading = true;
  String? _selectedCategory;
  List<String> _categories = [];

  // Premium Colors
  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final query = _search.text.trim();
      final items = await _svc.list(search: query.isEmpty ? null : query);
      if (!mounted) return;
      
      final categories = items
          .where((a) => a.category != null && a.category!.isNotEmpty)
          .map((a) => a.category!)
          .toSet()
          .toList()
        ..sort();
      
      setState(() {
        _items = items;
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
      setState(() => _loading = false);
    }
  }

  List<Amenity> get _filteredItems {
    if (_selectedCategory == null) return _items;
    return _items.where((a) => a.category == _selectedCategory).toList();
  }

  Future<void> _createOrEdit([Amenity? item]) async {
    final result = await showModalBottomSheet<Amenity?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmenityForm(item: item),
    );

    if (result != null) {
      try {
        if (item == null) {
          await _svc.create(result);
          if (!mounted) return;
          showSnack(context, 'Đã thêm tiện ích mới thành công', error: false);
        } else {
          await _svc.update(result.id, result);
          if (!mounted) return;
          showSnack(context, 'Cập nhật tiện ích thành công', error: false);
        }
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Đã xảy ra lỗi: $e', error: true);
      }
      await _load();
    }
  }

  Future<void> _delete(Amenity a) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Xác nhận xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Bạn có chắc muốn xóa tiện ích "${a.name}" không? Hành động này không thể hoàn tác.', style: GoogleFonts.inter()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text('Xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          ],
        ));
    if (ok == true) {
      try {
        await _svc.delete(a.id);
        if (!mounted) return;
        showSnack(context, 'Đã xóa tiện ích');
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Lỗi: $e', error: true);
      }
      await _load();
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Quản lý dịch vụ → Tiện ích', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('${_items.length} tiện ích đang hoạt động', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -28,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: TextField(
              controller: _search,
              style: GoogleFonts.inter(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiện ích...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _search.clear();
                    _load();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityCard(Amenity a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _createOrEdit(a),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'amenity-${a.id}',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          image: (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                              ? DecorationImage(
                            image: NetworkImage(a.imageUrl!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: (a.imageUrl == null || a.imageUrl!.isEmpty)
                            ? Icon(Icons.spa, color: _primaryColor, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  a.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildActionMenu(a),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (a.category != null)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.grey[100],
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: Text(
                                 a.category!,
                                 style: GoogleFonts.inter(
                                   fontSize: 11,
                                   color: Colors.grey[700],
                                   fontWeight: FontWeight.w600
                                 ),
                               ),
                             ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (a.description != null && a.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    a.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge(a),
                    const Spacer(),
                    if ((a.pricePerHour ?? 0) > 0)
                      Text(
                        '${(a.pricePerHour ?? 0).toStringAsFixed(0)} đ/h',
                        style: GoogleFonts.inter(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(Amenity a) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') _createOrEdit(a);
        if (value == 'delete') _delete(a);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_rounded, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 12),
              Text('Chỉnh sửa', style: GoogleFonts.inter()),
            ])),
        PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_rounded, size: 20, color: Colors.red[400]),
              const SizedBox(width: 12),
              Text('Xóa', style: GoogleFonts.inter(color: Colors.red[400])),
            ])),
      ],
      child: const Icon(Icons.more_horiz, color: Colors.grey),
    );
  }

  Widget _buildStatusBadge(Amenity a) {
    final allowBooking = a.allowBooking ?? false;
    final manualApproval = a.requireManualApproval ?? false;
    
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (!allowBooking) {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[600]!;
      text = 'Ngưng hoạt động';
      icon = Icons.block_rounded;
    } else if (manualApproval) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      text = 'Cần duyệt';
      icon = Icons.access_time_rounded;
    } else {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      text = 'Tự động duyệt';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade300,
            ),
            boxShadow: isSelected 
                ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có dữ liệu tiện ích',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            'Bắt đầu bằng cách thêm tiện ích đầu tiên',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Quản lý tiện ích', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_amenity_fab',
        onPressed: () => _createOrEdit(),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildHeader(),
          if (_categories.isNotEmpty)
            Container(
              height: 60,
              margin: const EdgeInsets.only(top: 36, bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildCategoryChip(null, 'Tất cả'),
                  ..._categories.map((cat) => _buildCategoryChip(cat, cat)),
                ],
              ),
            )
          else 
            const SizedBox(height: 48),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _load,
              child: _filteredItems.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                itemCount: _filteredItems.length,
                itemBuilder: (_, i) => _buildAmenityCard(_filteredItems[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityForm extends StatefulWidget {
  final Amenity? item;
  const _AmenityForm({this.item});

  @override
  State<_AmenityForm> createState() => _AmenityFormState();
}

class _AmenityFormState extends State<_AmenityForm> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _imageUrl = TextEditingController();
  final _location = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _uploadedImageUrl;
  final _rules = TextEditingController();
  final _openStart = TextEditingController();
  final _openEnd = TextEditingController();
  final _minDur = TextEditingController();
  final _maxDur = TextEditingController();
  final _maxAdv = TextEditingController();
  final _maxPerDay = TextEditingController();
  final _maxPerWeek = TextEditingController();

  bool _allowBooking = true;
  bool _requireManual = false;
  bool _requirePrepay = false;
  String? _selectedCategory;
  List<String> _categories = [];
  bool _loadingCategories = false;
  final _svc = AmenitiesService();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
    _fillData();
  }
  
  void _fillData() {
    if (widget.item != null) {
      final a = widget.item!;
      _name.text = a.name;
      _desc.text = a.description ?? '';
      _price.text = a.pricePerHour?.toString() ?? '';
      _selectedCategory = a.category;
      _imageUrl.text = a.imageUrl ?? '';
      _uploadedImageUrl = a.imageUrl;
      _location.text = a.location ?? '';
      _rules.text = a.usageRules ?? '';
      _openStart.text = a.openHourStart?.toString() ?? '6';
      _openEnd.text = a.openHourEnd?.toString() ?? '22';
      _minDur.text = a.minDurationMinutes?.toString() ?? '60';
      _maxDur.text = a.maxDurationMinutes?.toString() ?? '120';
      _maxAdv.text = a.maxAdvanceDays?.toString() ?? '7';
      _maxPerDay.text = a.maxPerDay?.toString() ?? '2';
      _maxPerWeek.text = a.maxPerWeek?.toString() ?? '5';
      _allowBooking = a.allowBooking ?? true;
      _requireManual = a.requireManualApproval ?? false;
      _requirePrepay = a.requirePrepayment ?? false;
    } else {
      _openStart.text = '6';
      _openEnd.text = '22';
      _minDur.text = '60';
      _maxDur.text = '120';
      _maxAdv.text = '7';
      _maxPerDay.text = '2';
      _maxPerWeek.text = '5';
      _allowBooking = true;
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await _svc.getCategories();
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _categories = AmenitiesService.defaultCategories;
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _imageUrl.dispose();
    _location.dispose();
    _rules.dispose();
    _openStart.dispose();
    _openEnd.dispose();
    _minDur.dispose();
    _maxDur.dispose();
    _maxAdv.dispose();
    _maxPerDay.dispose();
    _maxPerWeek.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Vui lòng kiểm tra lại thông tin', error: true);
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      showSnack(context, 'Vui lòng chọn loại tiện ích', error: true);
      return;
    }

    final m = Amenity(
      id: widget.item?.id ?? '',
      name: _name.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      pricePerHour: _price.text.trim().isEmpty ? null : double.tryParse(_price.text.trim()),
      allowBooking: _allowBooking,
      category: _selectedCategory!,
      imageUrl: (_uploadedImageUrl ?? _imageUrl.text.trim()).isEmpty ? null : (_uploadedImageUrl ?? _imageUrl.text.trim()),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      usageRules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
      openHourStart: int.tryParse(_openStart.text.trim()),
      openHourEnd: int.tryParse(_openEnd.text.trim()),
      minDurationMinutes: int.tryParse(_minDur.text.trim()),
      maxDurationMinutes: int.tryParse(_maxDur.text.trim()),
      maxAdvanceDays: int.tryParse(_maxAdv.text.trim()),
      maxPerDay: int.tryParse(_maxPerDay.text.trim()),
      maxPerWeek: int.tryParse(_maxPerWeek.text.trim()),
      requireManualApproval: _requireManual,
      requirePrepayment: _requirePrepay,
    );

    // Pop sau khi frame hoàn thành để tránh navigator locked
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context, m);
        }
      });
    }
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _uploadedImageUrl = null;
        });
        await _uploadImage(_selectedImage!);
      }
    } catch (e) {
      if(mounted) showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path, filename: 'amenity_${DateTime.now().millisecondsSinceEpoch}.jpg'),
      });
      final response = await api.dio.post('/api/Amenities/upload-image', data: formData);
      if (response.data['url'] != null) {
        setState(() {
          _uploadedImageUrl = response.data['url'] as String;
          _imageUrl.text = _uploadedImageUrl!;
        });
      }
    } catch (e) {
      if(mounted) showSnack(context, 'Lỗi upload: $e', error: true);
    }
  }

  Widget _buildTextField(TextEditingController controller, {required String label, int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF009688), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (label.contains('*') && (value == null || value.trim().isEmpty)) {
            return 'Không được để trống trường này';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text(widget.item == null ? 'Thêm tiện ích mới' : 'Chỉnh sửa tiện ích', 
           style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF009688),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF009688),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Thời gian'),
            Tab(text: 'Thiết lập'),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _pickImage(ImageSource.gallery),
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                image: (_selectedImage != null || _uploadedImageUrl != null) ? DecorationImage(
                                  image: _selectedImage != null ? FileImage(_selectedImage!) as ImageProvider : NetworkImage(_uploadedImageUrl!),
                                  fit: BoxFit.cover,
                                ) : null,
                              ),
                              child: (_selectedImage == null && _uploadedImageUrl == null) ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('Chạm để thêm ảnh', style: GoogleFonts.inter(color: Colors.grey[500])),
                                ],
                              ) : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(_name, label: 'Tên tiện ích *'),
                          
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Loại tiện ích *',
                                filled: true,
                                fillColor: Colors.grey[50],
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF009688))),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter()))).toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v),
                            ),
                          ),
                          _buildTextField(_location, label: 'Vị trí'),
                          _buildTextField(_price, label: 'Giá (VNĐ/giờ)', isNumber: true),
                          _buildTextField(_desc, label: 'Mô tả', maxLines: 3),
                          _buildTextField(_rules, label: 'Quy định sử dụng', maxLines: 3),
                        ],
                      ),
                    ),
                    
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Giờ hoạt động', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_openStart, label: 'Mở (giờ)', isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField(_openEnd, label: 'Đóng (giờ)', isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Thời lượng đặt', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_minDur, label: 'Tối thiểu (phút)', isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField(_maxDur, label: 'Tối đa (phút)', isNumber: true)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text('Cho phép đặt chỗ', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text('Cư dân có thể đặt tiện ích này qua ứng dụng', style: GoogleFonts.inter(fontSize: 13)),
                            value: _allowBooking,
                            activeColor: const Color(0xFF009688),
                            onChanged: (v) => setState(() => _allowBooking = v),
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: Text('Cần duyệt thủ công', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text('Yêu cầu BQL duyệt trước khi hiệu lực', style: GoogleFonts.inter(fontSize: 13)),
                            value: _requireManual,
                            activeColor: const Color(0xFF009688),
                            onChanged: (v) => setState(() => _requireManual = v),
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: Text('Yêu cầu thanh toán trước', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text('Cư dân phải thanh toán ngay khi đặt', style: GoogleFonts.inter(fontSize: 13)),
                            value: _requirePrepay,
                            activeColor: const Color(0xFF009688),
                            onChanged: (v) => setState(() => _requirePrepay = v),
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text('Giới hạn đặt chỗ', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildTextField(_maxAdv, label: 'Đặt trước tối đa (ngày)', isNumber: true),
                          _buildTextField(_maxPerDay, label: 'Lượt tối đa / ngày', isNumber: true),
                          _buildTextField(_maxPerWeek, label: 'Lượt tối đa / tuần', isNumber: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Lưu tiện ích', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}