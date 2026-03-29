import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import 'complaints_service.dart';
import 'complaint_model.dart';

// Helper function để chuyển UTC sang giờ Việt Nam (UTC+7)
DateTime toVietnamTime(DateTime utcTime) {
  return utcTime.add(const Duration(hours: 7));
}

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});
  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  final _svc = ComplaintsService();
  final _items = <ComplaintModel>[];
  final _sc = ScrollController();
  bool _loading = false, _done = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _sc.addListener(_onScroll);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_sc.hasClients) return;
    if (_sc.position.pixels > _sc.position.maxScrollExtent - 100 &&
        !_loading &&
        !_done)
      _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _page = 1;
        _done = false;
        _items.clear();
      }
      final (data, total) = await _svc.getMyComplaints(page: _page);
      if (mounted) {
        setState(() {
          _items.addAll(data);
          if (data.length < 20 || _items.length >= total) _done = true;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải phản ánh: ${e.toString()}', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Header
          _buildHeader(),

          // 2. Danh sách phản ánh
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mark_chat_unread_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có phản ánh',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhấn nút + để gửi phản ánh mới',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      controller: _sc,
                      padding: const EdgeInsets.only(
                        top: 20,
                        left: 16,
                        right: 16,
                        bottom: 80,
                      ),
                      itemCount: _items.length + 1,
                      itemBuilder: (c, i) {
                        if (i == _items.length)
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const SizedBox.shrink(),
                            ),
                          );
                        final m = _items[i];

                        // Modern status colors with gradients
                        final statusColor = m.status == 'Pending'
                            ? Colors.orange
                            : m.status == 'InProgress'
                            ? Colors.blue
                            : m.status == 'Resolved'
                            ? Colors.green
                            : Colors.grey;

                        final gradientColors = m.status == 'Pending'
                            ? [
                                Colors.orange.shade400,
                                Colors.deepOrange.shade600,
                              ]
                            : m.status == 'InProgress'
                            ? [Colors.blue.shade400, Colors.indigo.shade600]
                            : m.status == 'Resolved'
                            ? [Colors.green.shade400, Colors.teal.shade600]
                            : [Colors.grey.shade400, Colors.grey.shade600];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: isDark
                                ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.surfaceContainerHighest,
                                      theme.colorScheme.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? theme.colorScheme.primary
                                            : statusColor)
                                        .withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: isDark ? 0 : 4,
                            color: isDark
                                ? Colors.transparent
                                : theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: isDark
                                  ? BorderSide(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3),
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push(
                                  c,
                                  MaterialPageRoute(
                                    builder: (_) => _ComplaintDetail(m),
                                  ),
                                );
                                if (result == true) _load(refresh: true);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.title,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradientColors,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: statusColor.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _getStatusText(m.status),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.category,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getCategoryText(m.category),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(() {
                                          final vnTime = toVietnamTime(
                                            m.createdAtUtc,
                                          );
                                          return '${vnTime.day}/${vnTime.month}/${vnTime.year}';
                                        }(), style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      m.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(height: 1.5),
                                    ),
                                    if (m.phanHoiAdmin != null &&
                                        m.phanHoiAdmin!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDark
                                                ? [
                                                    Colors.blue.shade900
                                                        .withOpacity(0.3),
                                                    Colors.blue.shade800
                                                        .withOpacity(0.2),
                                                  ]
                                                : [
                                                    Colors.blue.shade50,
                                                    Colors.cyan.shade50,
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.withOpacity(
                                              isDark ? 0.5 : 0.3,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.reply,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.blue.shade200
                                                  : Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Phản hồi: ${m.phanHoiAdmin}',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.blue.shade100
                                                      : Colors.blue.shade900,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _CreateComplaint()),
        ).then((_) => _load(refresh: true)),
        label: const Text('Gửi phản ánh'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending':
        return 'Chưa xử lý';
      case 'InProgress':
        return 'Đang xử lý';
      case 'Resolved':
        return 'Đã xử lý';
      case 'Rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'Sanitation':
        return 'Vệ sinh';
      case 'Security':
        return 'An ninh';
      case 'Service':
        return 'Dịch vụ';
      case 'Other':
        return 'Khác';
      default:
        return category;
    }
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        45,
        16,
        40,
      ), // Reduced from 20,50,20,60
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1A237E), // Deep indigo
                  const Color(0xFF4A148C), // Deep purple
                  const Color(0xFF006064), // Deep cyan
                ]
              : [
                  const Color(0xFF0091EA), // Bright blue
                  const Color(0xFF00B8D4), // Cyan
                  const Color(0xFF00BFA5), // Teal
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24), // Reduced from 30
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
            // Nút quay lại - compact
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false);
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Quay lại',
            ),
            const SizedBox(height: 12), // Reduced from 8
            Text(
              'Dịch vụ cư dân',
              style: GoogleFonts.montserrat(
                // Modern font
                color: Colors.white.withOpacity(0.85),
                fontSize: 12, // Reduced from 14
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4
            Text(
              'Phản ánh',
              style: GoogleFonts.montserrat(
                // Modern font
                color: Colors.white,
                fontSize: 24, // Reduced from 28
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8), // Reduced from 4
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ), // Slightly reduced
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
                '${_items.length} phản ánh',
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
    );
  }
}

class _CreateComplaint extends StatefulWidget {
  const _CreateComplaint();
  @override
  State<_CreateComplaint> createState() => _CreateComplaintState();
}

class _CreateComplaintState extends State<_CreateComplaint> {
  final _f = GlobalKey<FormState>();
  final _t = TextEditingController();
  final _c = TextEditingController();
  final _email = TextEditingController();
  final _ten = TextEditingController();
  final _imagePicker = ImagePicker();
  String _cat = 'Other';
  bool _loading = false;
  bool _uploadingImages = false;
  List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = [];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        // Upload ngay lập tức
        await _uploadImage(image);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi chọn ảnh: $e', error: true);
      }
    }
  }

  Future<void> _uploadImage(XFile imageFile) async {
    setState(() => _uploadingImages = true);
    try {
      final imageUrl = await ComplaintsService().uploadImage(imageFile);
      setState(() {
        _uploadedImageUrls.add(imageUrl);
      });
      if (mounted) {
        showSnack(context, 'Đã upload ảnh thành công', error: false);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi upload ảnh: $e', error: true);
      }
      // Xóa ảnh khỏi danh sách nếu upload thất bại
      setState(() {
        _selectedImages.remove(imageFile);
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingImages = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _t.dispose();
    _c.dispose();
    _email.dispose();
    _ten.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gửi phản ánh',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        toolbarHeight: 56, // Compact height
        flexibleSpace: Container(
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
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [Colors.grey.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _f,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Info Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2C3E50), const Color(0xFF34495E)]
                            : [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.feedback_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thông tin phản ánh',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vui lòng cung cấp đầy đủ thông tin',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _t,
                          style: GoogleFonts.inter(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Tiêu đề *',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            floatingLabelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                            hintText: 'Nhập tiêu đề phản ánh của bạn',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: Icon(
                              Icons.title_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2.5,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 20,
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Vui lòng nhập tiêu đề'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _c,
                          style: GoogleFonts.inter(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Nội dung *',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            floatingLabelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                            hintText: 'Mô tả chi tiết vấn đề bạn gặp phải...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Icon(
                                Icons.description_rounded,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2.5,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 20,
                            ),
                          ),
                          minLines: 5,
                          maxLines: 10,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Vui lòng mô tả chi tiết'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _cat,
                          style: GoogleFonts.inter(fontSize: 15),
                          items: [
                            DropdownMenuItem(
                              value: 'Sanitation',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cleaning_services_rounded,
                                    size: 20,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Vệ sinh'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Security',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.security_rounded,
                                    size: 20,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('An ninh'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Service',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.room_service_rounded,
                                    size: 20,
                                    color: Colors.orange.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Dịch vụ'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.more_horiz_rounded,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Khác'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _cat = v ?? 'Other'),
                          decoration: InputDecoration(
                            labelText: 'Loại phản ánh',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            floatingLabelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                            prefixIcon: Icon(
                              Icons.category_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2.5,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Image Upload Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2C3E50), const Color(0xFF34495E)]
                            : [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.secondary.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade400,
                                    Colors.deepPurple.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.photo_library_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hình ảnh',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Thêm ảnh minh họa cho phản ánh',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_uploadingImages)
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Add Image Button
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _uploadingImages
                                  ? [Colors.grey.shade300, Colors.grey.shade400]
                                  : [
                                      theme.colorScheme.primary.withOpacity(
                                        0.1,
                                      ),
                                      theme.colorScheme.secondary.withOpacity(
                                        0.1,
                                      ),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _uploadingImages
                                  ? null
                                  : _showImageSourceDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 22,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Thêm ảnh',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Hiển thị ảnh đã chọn với animation
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            File(_selectedImages[index].path),
                                            width: 130,
                                            height: 130,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Colors.red,
                                                Colors.deepOrange,
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withOpacity(
                                                  0.5,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                            iconSize: 18,
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            onPressed: () =>
                                                _removeImage(index),
                                          ),
                                        ),
                                      ),
                                      if (index < _uploadedImageUrls.length)
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Colors.green,
                                                  Colors.teal,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.5),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Đã tải',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        // Contact Info Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      const Color(0xFF2C3E50),
                                      const Color(0xFF34495E),
                                    ]
                                  : [Colors.white, Colors.grey.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.orange,
                                          Colors.deepOrange,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.contact_mail_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thông tin liên hệ',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tùy chọn',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _ten,
                                style: GoogleFonts.inter(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Tên người gửi',
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  floatingLabelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                  hintText: 'Nhập tên của bạn',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2.5,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _email,
                                style: GoogleFonts.inter(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  floatingLabelStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                  hintText: 'email@example.com',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2.5,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 20,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Modern gradient submit button
                        Container(
                          height: 60,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (_loading || _uploadingImages)
                                  ? [Colors.grey.shade400, Colors.grey.shade600]
                                  : [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.secondary,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: (_loading || _uploadingImages)
                                    ? Colors.grey.withOpacity(0.3)
                                    : theme.colorScheme.primary.withOpacity(
                                        0.5,
                                      ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (_loading || _uploadingImages)
                                  ? null
                                  : () async {
                                      if (!_f.currentState!.validate()) return;
                                      setState(() => _loading = true);
                                      try {
                                        // Gửi danh sách URL ảnh đã upload
                                        final mediaUrls =
                                            _uploadedImageUrls.isNotEmpty
                                            ? _uploadedImageUrls.join('||')
                                            : null;
                                        await ComplaintsService().create(
                                          title: _t.text.trim(),
                                          content: _c.text.trim(),
                                          category: _cat,
                                          tenNguoiGui: _ten.text.trim().isEmpty
                                              ? null
                                              : _ten.text.trim(),
                                          emailNguoiGui:
                                              _email.text.trim().isEmpty
                                              ? null
                                              : _email.text.trim(),
                                          mediaUrls: mediaUrls,
                                        );
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        showSnack(
                                          context,
                                          'Đã gửi phản ánh thành công.',
                                        );
                                      } catch (e) {
                                        showSnack(
                                          context,
                                          'Lỗi gửi phản ánh: $e',
                                          error: true,
                                        );
                                      } finally {
                                        setState(() => _loading = false);
                                      }
                                    },
                              borderRadius: BorderRadius.circular(18),
                              child: Center(
                                child: (_loading || _uploadingImages)
                                    ? const SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Gửi phản ánh',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ), // Close Center
                            ), // Close InkWell
                          ), // Close Material
                        ), // Close Container
                        const SizedBox(height: 20),
                      ], // Close children array of Column (line 589)
                    ), // Close Column (line 587)
                  ), // Close Form (line 585)
                ], // Close children array of ListView (line 584)
              ), // Close ListView (line 582)
            ), // Close Container & body (line 572)
          ], // Additional closing bracket
        ), // Additional closing parenthesis
      ), // Additional closing parenthesis
    ); // Close Scaffold (line 538)
  }
}

class _ComplaintDetail extends StatefulWidget {
  final ComplaintModel m;
  const _ComplaintDetail(this.m);
  @override
  State<_ComplaintDetail> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<_ComplaintDetail> {
  final _svc = ComplaintsService();
  final _commentController = TextEditingController();
  ComplaintModel? _detail;
  bool _loading = true;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      _detail = await _svc.getDetails(widget.m.id);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải chi tiết: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await _svc.addComment(widget.m.id, _commentController.text.trim());
      _commentController.clear();
      // Reload detail to get updated comments
      await _loadDetail();
      if (mounted) {
        showSnack(context, 'Đã gửi tin nhắn');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi gửi tin nhắn: $e', error: true);
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _detail ?? widget.m;
    final theme = Theme.of(context);
    final statusColor = m.status == 'Pending'
        ? Colors.orange
        : m.status == 'InProgress'
        ? Colors.blue
        : m.status == 'Resolved'
        ? Colors.green
        : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết phản ánh'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.secondaryContainer,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      _getStatusText(m.status),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(_getCategoryText(m.category)),
                                    avatar: Icon(Icons.category, size: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(() {
                                    final vnTime = toVietnamTime(
                                      m.createdAtUtc,
                                    );
                                    return 'Ngày gửi: ${vnTime.day.toString().padLeft(2, '0')}/${vnTime.month.toString().padLeft(2, '0')}/${vnTime.year} ${vnTime.hour.toString().padLeft(2, '0')}:${vnTime.minute.toString().padLeft(2, '0')}';
                                  }(), style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Nội dung
                        Text(
                          'Nội dung phản ánh',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m.content,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        // Hiển thị ảnh
                        if (m.mediaUrls != null && m.mediaUrls!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Hình ảnh',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildImageGallery(m.mediaUrls!, theme),
                        ],
                        // Phản hồi admin (legacy)
                        if (m.phanHoiAdmin != null &&
                            m.phanHoiAdmin!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.cyan.shade50,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Phản hồi từ Ban quản lý',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  m.phanHoiAdmin!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                if (m.ngayCapNhat != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    () {
                                      final vnTime = toVietnamTime(
                                        m.ngayCapNhat!,
                                      );
                                      return 'Ngày phản hồi: ${vnTime.day.toString().padLeft(2, '0')}/${vnTime.month.toString().padLeft(2, '0')}/${vnTime.year} ${vnTime.hour.toString().padLeft(2, '0')}:${vnTime.minute.toString().padLeft(2, '0')}';
                                    }(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        // Chat section
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cuộc trò chuyện',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Comments list
                        if (m.comments != null && m.comments!.isNotEmpty)
                          ...m.comments!.map(
                            (comment) => _buildChatBubble(comment, theme),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Chưa có tin nhắn nào',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Input area
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Nhập tin nhắn...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sendingComment ? null : _sendComment,
                          icon: _sendingComment
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  color: theme.colorScheme.primary,
                                ),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            padding: const EdgeInsets.all(12),
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

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending':
        return 'Chưa xử lý';
      case 'InProgress':
        return 'Đang xử lý';
      case 'Resolved':
        return 'Đã xử lý';
      case 'Rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'Sanitation':
        return 'Vệ sinh';
      case 'Security':
        return 'An ninh';
      case 'Service':
        return 'Dịch vụ';
      case 'Other':
        return 'Khác';
      default:
        return category;
    }
  }

  List<String> _parseMediaUrls(String? raw) {
    final data = raw?.trim();
    if (data == null || data.isEmpty) return [];
    if (data.contains('||')) {
      return data.split('||').where((url) => url.trim().isNotEmpty).toList();
    }
    return [data];
  }

  Widget _buildImageGallery(String mediaUrls, ThemeData theme) {
    final urls = _parseMediaUrls(mediaUrls);
    if (urls.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) {
        final url = urls[index].trim();
        return GestureDetector(
          onTap: () {
            // Mở ảnh fullscreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    _ImageViewer(urls: urls, initialIndex: index),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: url.startsWith('data:image') && url.contains(',')
                  ? Image.memory(
                      base64Decode(url.substring(url.indexOf(',') + 1)),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatBubble(CommentModel comment, ThemeData theme) {
    final isAdmin = comment.isAdmin == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAdmin
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isAdmin ? const Radius.circular(4) : null,
                  bottomLeft: !isAdmin ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.userName != null)
                    Text(
                      comment.userName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAdmin
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (comment.userName != null) const SizedBox(height: 4),
                  Text(
                    comment.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isAdmin
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    () {
                      final vnTime = toVietnamTime(comment.createdAtUtc);
                      return '${vnTime.hour.toString().padLeft(2, '0')}:${vnTime.minute.toString().padLeft(2, '0')}';
                    }(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isAdmin
                          ? theme.colorScheme.onPrimaryContainer.withOpacity(
                              0.7,
                            )
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget để xem ảnh fullscreen
class _ImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImageViewer({required this.urls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index].trim();
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: url.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(url.split(',')[1]),
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
