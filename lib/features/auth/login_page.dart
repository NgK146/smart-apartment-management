import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../../core/services/biometric_service.dart';
import 'auth_provider.dart';
import 'auth_service.dart';
import '../manager/manager_shell.dart';
import '../shell/app_shell.dart';
import 'register_page.dart';
import 'not_approved_page.dart';
import 'forgot_password_email_page.dart';

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _f = GlobalKey<FormState>();
  final _u = TextEditingController(), _p = TextEditingController();
  bool _loading = false, _obscure = true;
  final _biometricService = BiometricService();
  bool _isBiometricAvailable = false;
  String? _biometricUsername;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _animController.dispose();
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isSupported = await _biometricService.isDeviceSupported();
      final hasBiometrics = await _biometricService.hasBiometrics();
      if (isSupported && hasBiometrics) {
        final usernames = await _biometricService.getLinkedUsernames();
        setState(() {
          _isBiometricAvailable = true;
          if (usernames.isNotEmpty) {
            _biometricUsername = usernames.first;
            _u.text = _biometricUsername!;
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric: $e');
    }
  }

  Future<void> _loginWithBiometric() async {
    if (!_isBiometricAvailable) {
      showSnack(context, 'Thiết bị không hỗ trợ vân tay', error: true);
      return;
    }

    if (_biometricUsername == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Chưa liên kết vân tay', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Text('Bạn cần đăng nhập bằng username/password trước, sau đó vào mục "Hồ sơ" để liên kết vân tay.', style: GoogleFonts.inter()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Đóng', style: GoogleFonts.inter()))],
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      final credentials = await _biometricService.authenticateForLogin();
      if (credentials == null) {
        if (mounted) showSnack(context, 'Xác thực vân tay thất bại hoặc không tìm thấy thông tin đăng nhập', error: true);
        return;
      }
      await context.read<AuthState>().login(credentials['username']!, credentials['password']!);
      if (!mounted) return;
      final auth = context.read<AuthState>();
      showSnack(context, 'Đăng nhập thành công! Chào mừng ${auth.fullName ?? auth.username ?? ""}');
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (auth.isManagerLike) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManagerShell()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Đăng nhập thất bại';
      if (e.toString().contains('401') || e.toString().contains('Sai username')) {
        errorMessage = 'Sai tên đăng nhập hoặc mật khẩu. Vui lòng đăng nhập lại bằng username/password và liên kết lại vân tay.';
      } else if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
        errorMessage = 'Bạn không có quyền truy cập';
      } else if (e.toString().contains('Network') || e.toString().contains('timeout')) {
        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', '');
      }
      showSnack(context, errorMessage, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _f,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Logo & Title Section
                                Column(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [const Color(0xFF009688), const Color(0xFF00695C)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: const Color(0xFF009688).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                                      ),
                                      child: const Icon(Icons.apartment, color: Colors.white, size: 45),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'ICitizen',
                                      style: GoogleFonts.inter(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF009688),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chào mừng trở lại',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),

                                // Username Field
                                TextFormField(
                                  controller: _u,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: 'Tên đăng nhập',
                                    labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                                    prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF009688)),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF009688), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  ),
                                  validator: (v)=> (v==null||v.isEmpty)?'Vui lòng nhập tên đăng nhập':null,
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                TextFormField(
                                  controller: _p,
                                  obscureText: _obscure,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: 'Mật khẩu',
                                    labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                                    prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF009688)),
                                    suffixIcon: IconButton(
                                      onPressed: ()=> setState(()=> _obscure = !_obscure),
                                      icon: Icon(_obscure? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[400]),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF009688), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  ),
                                  validator: (v)=> (v==null||v.length<6)?'Mật khẩu phải có ít nhất 6 ký tự':null,
                                ),
                                
                                // Fingerprint Section
                                if (_isBiometricAvailable) ...[
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text('hoặc', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton(
                                    onPressed: _loading ? null : _loginWithBiometric,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide(color: _biometricUsername != null ? const Color(0xFF009688) : Colors.grey[300]!, width: 2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.fingerprint, size: 28, color: _biometricUsername != null ? const Color(0xFF009688) : Colors.grey[400]),
                                        const SizedBox(width: 12),
                                        Text(
                                          _biometricUsername != null ? 'Đăng nhập bằng vân tay' : 'Chưa liên kết vân tay',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _biometricUsername != null ? const Color(0xFF009688) : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 32),

                                // Login Button
                                FilledButton(
                                  onPressed: _loading? null : () async {
                                    if(!_f.currentState!.validate()) return;
                                    setState(()=>_loading=true);
                                    try {
                                      await context.read<AuthState>().login(_u.text.trim(), _p.text);
                                      if (!mounted) return;
                                      final auth = context.read<AuthState>();
                                      showSnack(context, 'Đăng nhập thành công! Chào mừng ${auth.fullName ?? auth.username ?? ""}');
                                      await Future.delayed(const Duration(milliseconds: 500));
                                      if (!mounted) return;
                                      if (auth.isManagerLike) {
                                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const ManagerShell()));
                                      } else {
                                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const AppShell()));
                                      }
                                    } on NotApprovedException catch (_) {
                                      if (!mounted) return;
                                      Navigator.push(context, MaterialPageRoute(builder: (_)=> NotApprovedPage(username: _u.text.trim(), password: _p.text)));
                                    } catch (e) {
                                      if (!mounted) return;
                                      String errorMessage = 'Đăng nhập thất bại';
                                      if (e.toString().contains('401') || e.toString().contains('Sai username')) {
                                        errorMessage = 'Sai tên đăng nhập hoặc mật khẩu';
                                      } else if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
                                        errorMessage = 'Bạn không có quyền truy cập';
                                      } else if (e.toString().contains('Network') || e.toString().contains('timeout')) {
                                        errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet';
                                      } else {
                                        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', '');
                                      }
                                      showSnack(context, errorMessage, error: true);
                                    } finally { if(mounted) setState(()=>_loading=false); }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF009688),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _loading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.login, size: 22),
                                            const SizedBox(width: 10),
                                            Text('Đăng nhập', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          ],
                                        ),
                                ),
                                
                                const SizedBox(height: 24),

                                // Footer Links
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordEmailPage())),
                                      child: Text('Quên mật khẩu?', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF009688), fontWeight: FontWeight.w600)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                                      child: Text('Đăng ký', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF009688), fontWeight: FontWeight.w600)),
                                    ),
                                  ],
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
        ),
      ),
    );
  }
}
