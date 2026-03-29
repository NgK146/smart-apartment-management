import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/config_url.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class CreatePostScreen extends StatefulWidget {
  final PostType type;
  final CommunityPost? post; // Nếu có thì là chế độ sửa

  const CreatePostScreen({
    super.key,
    required this.type,
    this.post,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _postService = CommunityPostService();

  List<String> _imageUrls = [];
  bool _isUploading = false;
  bool _isSaving = false;

  // [THÊM MỚI] Màu Theme để đồng bộ Gradient
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);


  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _titleController.text = widget.post!.title;
      _contentController.text = widget.post!.content;
      _imageUrls = List.from(widget.post!.imageUrls);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (images.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      // TODO: Implement Upload images to server and get URLs
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tính năng upload ảnh đang được phát triển')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.post != null) {
        // Cập nhật bài đăng
        await _postService.updatePost(
          postId: widget.post!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrls: _imageUrls,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật bài đăng')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Tạo bài đăng mới
        await _postService.createPost(
          type: widget.type,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrls: _imageUrls.isNotEmpty ? _imageUrls : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đăng bài thành công')),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getTitle() {
    if (widget.post != null) return 'Sửa bài đăng';
    switch (widget.type) {
      case PostType.news:
        return 'Đăng tin tức';
      case PostType.discussion:
        return 'Tạo thảo luận';
      case PostType.suggestion:
        return 'Gửi kiến nghị';
    }
  }

  String _getHintText() {
    switch (widget.type) {
      case PostType.news:
        return 'Nhập nội dung tin tức...';
      case PostType.discussion:
        return 'Chia sẻ suy nghĩ của bạn...';
      case PostType.suggestion:
        return 'Mô tả kiến nghị của bạn...';
    }
  }

  // Helper cho input field
  InputDecoration _getInputDecoration({required String label, String? hint, int? maxLines}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
      fillColor: _backgroundColor, // Dùng màu nền light grey
      alignLabelWithHint: maxLines != null && maxLines > 1,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Nền trắng cho form, không dùng _backgroundColor
      appBar: AppBar(
        title: Text(_getTitle()),
        // [NÂNG CẤP] Thêm Gradient vào AppBar
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent, // Đảm bảo gradient hiển thị
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _savePost,
              child: const Text('Đăng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // [NÂNG CẤP] Sử dụng styling input mới
            TextFormField(
              controller: _titleController,
              decoration: _getInputDecoration(
                  label: 'Tiêu đề',
                  hint: 'Nhập tiêu đề bài đăng'
              ),
              maxLength: 200,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: _getInputDecoration(
                label: 'Nội dung',
                hint: _getHintText(),
                maxLines: 10,
              ),
              maxLines: 10,
              maxLength: 5000,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập nội dung';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Phần hình ảnh
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickImages,
                  icon: _isUploading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.photo_library),
                  label: const Text('Thêm ảnh'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
                if (_imageUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text('${_imageUrls.length} ảnh đã chọn', style: TextStyle(color: Colors.grey[600])),
                  ),
              ],
            ),
            if (_imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              AppConfig.resolve(_imageUrls[index]),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => _removeImage(index),
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
          ],
        ),
      ),
    );
  }
}