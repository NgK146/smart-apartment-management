import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import 'auth_service.dart';
import '../apartments/apartments_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  final _apartmentsService = ApartmentsService();
  List<Apartment> _availableApartments = [];
  Apartment? _selectedApartment;
  bool _loadingApartments = false;
  final _nationalIdController = TextEditingController();
  String _residentType = 'Owner';
  
  static const _roles = ['Resident', 'Vendor'];
  String _selectedRole = 'Resident';
  final _inviteCodeController = TextEditingController();
  
  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  Future<void> _loadApartments() async {
    setState(() => _loadingApartments = true);
   try {
      _availableApartments = await _apartmentsService.getAvailable();
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _loadingApartments = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    if (!_formKey.currentState!.validate()) return false;
    if (_passwordController.text != _confirmPasswordController.text) {
      showSnack(context, 'Mật khẩu xác nhận không khớp', error: true);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_selectedRole == 'Resident') {
      if (_selectedApartment == null) {
        showSnack(context, 'Vui lòng chọn căn hộ', error: true);
        return false;
      }
      if (_nationalIdController.text.trim().isEmpty) {
        showSnack(context, 'Vui lòng nhập CMND/CCCD', error: true);
        return false;
      }
    } else if (_selectedRole == 'Vendor') {
      if (_inviteCodeController.text.trim().isEmpty) {
        showSnack(context, 'Vendor cần nhập mã mời/mã công ty', error: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
      if (_selectedRole == 'Resident') {
        await _loadApartments();
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => _currentStep = 1);
      } else {
        await _doRegister();
      }
    } else {
      if (!_validateStep2()) return;
      await _doRegister();
    }
  }

  Future<void> _doRegister() async {
    setState(() => _loading = true);
    try {
      final msg = await AuthService().register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        desiredRole: _selectedRole,
        inviteCode: _selectedRole == 'Vendor' ? _inviteCodeController.text.trim() : null,
        apartmentCode: _selectedRole == 'Resident' && _selectedApartment != null ? _selectedApartment!.code : null,
        nationalId: _selectedRole == 'Resident' ? _nationalIdController.text.trim() : null,
        residentType: _selectedRole == 'Resident' ? _residentType : null,
      );
      if (!mounted) return;
      showSnack(context, 'Đăng ký thành công! $msg');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Đăng ký thất bại';
      if (e.toString().contains('Username') || e.toString().contains('đã tồn tại')) {
        errorMessage = 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác';
      } else if (e.toString().contains('Email') || e.toString().contains('email')) {
        errorMessage = 'Email không hợp lệ hoặc đã được sử dụng';
      } else if (e.toString().contains('Phone') || e.toString().contains('phone')) {
        errorMessage = 'Số điện thoại không hợp lệ hoặc đã được sử dụng';
      } else if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
        errorMessage = 'Bạn không có quyền đăng ký với vai trò này';
      } else if (e.toString().contains('Network') || e.toString().contains('timeout')) {
        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', '');
        if (errorMessage.length > 100) errorMessage = errorMessage.substring(0, 100) + '...';
      }
      showSnack(context, errorMessage, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF009688), const Color(0xFF00695C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                    ),
                    Text(
                      _currentStep == 0 ? 'Đăng ký - Bước 1' : 'Đăng ký - Bước 2',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 550),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Progress Indicator
                                    Row(
                                      children: [
                                        Expanded(child: _buildStepIndicator(1, _currentStep + 1, 'Tạo tài khoản')),
                                        if (_selectedRole == 'Resident') ...[
                                          Container(
                                            width: 40,
                                            height: 3,
                                            margin: const EdgeInsets.only(bottom: 30),
                                            decoration: BoxDecoration(
                                              color: _currentStep >= 1 ? const Color(0xFF009688) : Colors.grey[300],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          Expanded(child: _buildStepIndicator(2, _currentStep + 1, 'Liên kết căn hộ')),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    
                                    // Page View
                                    SizedBox(
                                      height: _currentStep == 0 ? 620 : 580,
                                      child: PageView(
                                        controller: _pageController,
                                        physics: const NeverScrollableScrollPhysics(),
                                        children: [_buildStep1(), _buildStep2()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, int currentStep, String label) {
    final isActive = step <= currentStep;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? LinearGradient(colors: [const Color(0xFF009688), const Color(0xFF00695C)])
                : null,
            color: isActive ? null : Colors.grey[200],
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFF009688).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))] : null,
          ),
          child: Center(
            child: isActive && step < currentStep
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : Text(step.toString(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey[500])),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? const Color(0xFF009688) : Colors.grey[500])),
      ],
    );
  }

  Widget _buildStep1() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text('Thông tin cá nhân',style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 20),
        _buildTextField(_fullNameController, 'Họ và Tên *', Icons.badge_outlined, required: true),
        const SizedBox(height: 16),
        _buildTextField(_phoneController, 'Số điện thoại *', Icons.phone_outlined, keyboardType: TextInputType.phone, required: true, helperText: 'VD: 0912345678'),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress, helperText: 'Dùng để nhận thông báo'),
        const SizedBox(height: 16),
        _buildTextField(_usernameController, 'Tên đăng nhập *', Icons.person_outline, required: true),
        const SizedBox(height: 16),
        _buildPasswordField(_passwordController, 'Mật khẩu *', _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
        const SizedBox(height: 16),
        _buildPasswordField(_confirmPasswordController, 'Xác nhận mật khẩu *', _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
        const SizedBox(height: 20),
        Text('Chọn vai trò', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: _roles.map((r) => _buildRoleChip(r)).toList(),
        ),
        if (_selectedRole == 'Vendor') ...[
          const SizedBox(height: 16),
          _buildTextField(_inviteCodeController, 'Mã mời / Mã công ty *', Icons.qr_code_2, required: true),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF009688),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_selectedRole == 'Vendor' ? Icons.check : Icons.arrow_forward, size: 22),
                    const SizedBox(width: 10),
                    Text(_selectedRole == 'Vendor' ? 'Đăng ký' : 'Tiếp theo', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text('Liên kết căn hộ', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Vui lòng cung cấp thông tin để Ban quản lý xác thực', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),
        
        if (_loadingApartments)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_availableApartments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red[700], size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text('Không có căn hộ nào khả dụng. Vui lòng liên hệ Ban quản lý.', style: GoogleFonts.inter(color: Colors.red[800], fontSize: 14))),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<Apartment>(
              value: _selectedApartment,
              decoration: InputDecoration(
                labelText: 'Chọn căn hộ *',
                labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF009688)),
                border: InputBorder.none,
              ),
              items: _availableApartments.map((apt) {
                return DropdownMenuItem<Apartment>(
                  value: apt,
                  child: Text('${apt.code} - ${apt.building} (T.${apt.floor})', style: GoogleFonts.inter(fontSize: 15)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedApartment = value),
            ),
          ),
        const SizedBox(height: 16),
        _buildTextField(_nationalIdController, 'CMND/CCCD *', Icons.badge_outlined, keyboardType: TextInputType.number, helperText: 'CMND: 9 số, CCCD: 12 số', maxLength: 12, required: true),
        const SizedBox(height: 20),
        Text('Loại cư dân', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _buildResidentTypeChip('Owner', 'Chủ hộ'),
            _buildResidentTypeChip('Tenant', 'Người thuê'),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () {
                  _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  setState(() => _currentStep = 0);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFF009688), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back, color: Color(0xFF009688), size: 20),
                    const SizedBox(width: 8),
                    Text('Quay lại', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF009688))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 22),
                          const SizedBox(width: 10),
                          Text('Đăng ký', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool required = false, TextInputType? keyboardType, String? helperText, int? maxLength}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
        helperText: helperText,
        helperStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: const Color(0xFF009688)),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF009688), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập $label' : null : null,
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool obscure, VoidCallback onToggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
        prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF009688)),
        suffixIcon: IconButton(onPressed: onToggle, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[400])),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF009688), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
    );
  }

  Widget _buildRoleChip(String role) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          if (role == 'Vendor') {
            _currentStep = 0;
            _pageController.jumpToPage(0);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFF009688), Color(0xFF00695C)]) : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF009688) : Colors.grey[300]!, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF009688).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(role, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[700])),
      ),
    );
  }

  Widget _buildResidentTypeChip(String type, String label) {
    final isSelected = _residentType == type;
    return InkWell(
      onTap: () => setState(() => _residentType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFF009688), Color(0xFF00695C)]) : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF009688) : Colors.grey[300]!, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF009688).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[700])),
      ),
    );
  }
}
