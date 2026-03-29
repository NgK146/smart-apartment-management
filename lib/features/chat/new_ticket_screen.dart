import 'package:flutter/material.dart';
import '../chat/chat_service.dart';

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _submitting = false;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // Helper cho Input Decoration chuẩn
  InputDecoration _getInputDecoration({required String label, String? hint, int? maxLines}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
      fillColor: Colors.grey[50], // Nền xám nhạt cho input
      alignLabelWithHint: maxLines != null && maxLines > 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, // Nền chung cho form
      appBar: AppBar(
        title: const Text('Tạo yêu cầu hỗ trợ'),
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
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [NÂNG CẤP] Form Field 1
              TextFormField(
                controller: _titleController,
                decoration: _getInputDecoration(
                  label: 'Tiêu đề yêu cầu',
                  hint: 'Ví dụ: Sửa vòi nước bị rò rỉ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // [NÂNG CẤP] Form Field 2
              TextFormField(
                controller: _categoryController,
                decoration: _getInputDecoration(
                  label: 'Loại yêu cầu (tuỳ chọn)',
                  hint: 'Ví dụ: Kỹ thuật, An ninh, Vệ sinh...',
                ),
              ),
              const SizedBox(height: 12),
              // [NÂNG CẤP] Form Field 3
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: _getInputDecoration(
                  label: 'Mô tả chi tiết',
                  hint: 'Mô tả sự cố hoặc yêu cầu của bạn...',
                  maxLines: 6,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng mô tả chi tiết vấn đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Nút Gửi
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.send),
                  label: const Text('Gửi yêu cầu'),
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor, // Màu chủ đạo
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await SupportService().createTicket(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tạo yêu cầu: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}