import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import 'resident_service.dart';
import '../apartments/apartments_service.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';

class LinkApartmentPage extends StatefulWidget {
  const LinkApartmentPage({super.key});

  @override
  State<LinkApartmentPage> createState() => _LinkApartmentPageState();
}

class _LinkApartmentPageState extends State<LinkApartmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _apartmentsService = ApartmentsService();
  List<Apartment> _availableApartments = [];
  Apartment? _selectedApartment;
  bool _loadingApartments = false;
  final _nationalIdController = TextEditingController(); // CMND/CCCD
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  bool _loading = false;

  final Color _primaryColor = const Color(0xFF009688); // Teal
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadApartments();
  }

  Future<void> _loadApartments() async {
    setState(() => _loadingApartments = true);
    try {
      // Lấy danh sách căn hộ có sẵn (status = Available hoặc null)
      final allApartments = await _apartmentsService.listForResident(pageSize: 200);
      _availableApartments = allApartments.where((apt) => 
        apt.status == null || apt.status == 'Available'
      ).toList();
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải danh sách căn hộ: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loadingApartments = false);
    }
  }

  @override
  void dispose() {
    _nationalIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartment == null) {
      showSnack(context, 'Vui lòng chọn căn hộ', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      // Giả định ResidentService().linkApartment chấp nhận code thay vì id
      await ResidentService().linkApartment(
        apartmentCode: _selectedApartment!.code,
        nationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      );
      if (!mounted) return;
      await context.read<AuthState>().loadProfile();
      showSnack(context, 'Đã gửi yêu cầu liên kết căn hộ. Vui lòng chờ Ban quản lý duyệt.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi liên kết căn hộ: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Helper cho Input Decoration chuẩn
  InputDecoration _getInputDecoration({required String label, String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
      fillColor: Colors.white, // Nền trắng cho input nổi trên nền xám của Scaffold
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _backgroundColor, // Nền xám nhẹ
      appBar: AppBar(
        title: const Text('Liên kết căn hộ'),
        // [NÂNG CẤP] Dùng màu Teal chủ đạo cho Gradient
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            colors: [_primaryColor, Colors.teal.shade700],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          )),
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
              // [NÂNG CẤP] Hộp thông tin nổi bật
              Container(
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quy trình Liên kết', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: _primaryColor)),
                          const SizedBox(height: 4),
                          Text('Yêu cầu sẽ được gửi đến Ban quản lý. Vui lòng đảm bảo CMND/CCCD và căn hộ là chính xác để quá trình xác minh diễn ra nhanh chóng.', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Loading/Error State
              if (_loadingApartments)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_availableApartments.isEmpty)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Không có căn hộ nào khả dụng. Vui lòng liên hệ Ban quản lý.',
                            style: TextStyle(color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
              // [NÂNG CẤP] Dropdown Button
                DropdownButtonFormField<Apartment>(
                  value: _selectedApartment,
                  decoration: _getInputDecoration(label: 'Chọn Căn hộ *', icon: Icons.home),
                  items: _availableApartments.map((apt) {
                    return DropdownMenuItem<Apartment>(
                      value: apt,
                      child: Text('${apt.code} - ${apt.building} (Tầng ${apt.floor}${apt.areaM2 != null ? ', ${apt.areaM2!.toStringAsFixed(0)} m²' : ''})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedApartment = value);
                  },
                  validator: (v) => v == null ? 'Vui lòng chọn căn hộ' : null,
                ),
              const SizedBox(height: 16),

              // CMND/CCCD
              TextFormField(
                controller: _nationalIdController,
                decoration: _getInputDecoration(label: 'CMND/CCCD *', hint: 'Ví dụ: 001234567890', icon: Icons.badge),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập CMND/CCCD';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: _getInputDecoration(label: 'Số điện thoại liên hệ', hint: 'Ví dụ: 0901234567', icon: Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    // Kiểm tra định dạng số điện thoại Việt Nam (10-11 số)
                    final phoneRegex = RegExp(r'^(0|\+84)[3-9]\d{8,9}$');
                    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-]'), '');
                    if (!phoneRegex.hasMatch(cleaned)) {
                      return 'Số điện thoại không hợp lệ';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: _getInputDecoration(label: 'Email liên hệ', hint: 'Ví dụ: example@email.com', icon: Icons.email),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Email không hợp lệ';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mã xác thực
              TextFormField(
                controller: _verificationCodeController,
                decoration: _getInputDecoration(label: 'Mã xác thực (nếu có)', hint: 'Mã do Ban quản lý cung cấp', icon: Icons.vpn_key),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: _primaryColor, // Màu chủ đạo
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Gửi yêu cầu liên kết', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}