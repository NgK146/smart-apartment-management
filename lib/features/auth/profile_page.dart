import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/services/biometric_service.dart';
import 'auth_provider.dart';
import 'auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _biometricService = BiometricService();
  bool _isLoading = false;
  bool _isBiometricSupported = false;
  bool _hasBiometrics = false;
  bool _isBiometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      debugPrint('ProfilePage: Đang kiểm tra trạng thái vân tay...');
      _isBiometricSupported = await _biometricService.isDeviceSupported();
      _hasBiometrics = await _biometricService.hasBiometrics();
      _availableBiometrics = await _biometricService.getAvailableBiometrics();

      final auth = context.read<AuthState>();
      if (auth.username != null) {
        _isBiometricEnabled = await _biometricService.isBiometricEnabledForUser(auth.username!);
        debugPrint('ProfilePage: Trạng thái vân tay cho ${auth.username}: $_isBiometricEnabled');
      }
    } catch (e) {
      debugPrint('ProfilePage: Lỗi khi kiểm tra trạng thái vân tay: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Vân tay';
      case BiometricType.iris:
        return 'Mống mắt';
      case BiometricType.strong:
        return 'Xác thực mạnh';
      case BiometricType.weak:
        return 'Xác thực yếu';
    }
  }

  String _getBiometricTypeIcon(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return '👤';
      case BiometricType.fingerprint:
        return '👆';
      case BiometricType.iris:
        return '👁️';
      default:
        return '🔐';
    }
  }

  Future<void> _toggleBiometric() async {
    final auth = context.read<AuthState>();
    if (auth.username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin người dùng')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isBiometricEnabled) {
        // Hủy liên kết
        final success = await _biometricService.disableBiometricForUser(auth.username!);
        if (success) {
          setState(() => _isBiometricEnabled = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã hủy liên kết vân tay'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không thể hủy liên kết vân tay'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Liên kết vân tay - yêu cầu nhập password và verify
        final password = await _showPasswordDialog();
        if (password == null || password.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vui lòng nhập mật khẩu để liên kết vân tay'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Verify password bằng cách thử đăng nhập
        try {
          debugPrint('ProfilePage: Đang verify password...');
          await AuthService().login(auth.username!, password);
          debugPrint('ProfilePage: Password đúng, đang liên kết vân tay...');
          
          // Nếu đăng nhập thành công, password đúng → liên kết vân tay
          final success = await _biometricService.enableBiometricForUser(auth.username!, password);
          debugPrint('ProfilePage: Kết quả liên kết vân tay: $success');
          
          if (success) {
            // Refresh lại trạng thái
            await _checkBiometricStatus();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã liên kết vân tay thành công! Bây giờ bạn có thể đăng nhập bằng vân tay.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không thể liên kết vân tay. Có thể bạn đã hủy xác thực vân tay hoặc có lỗi xảy ra.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('ProfilePage: Lỗi khi verify password: $e');
          // Password sai hoặc lỗi đăng nhập
          if (mounted) {
            String errorMessage = 'Mật khẩu không đúng. Vui lòng thử lại.';
            if (e.toString().contains('401') || e.toString().contains('Sai username')) {
              errorMessage = 'Mật khẩu không đúng. Vui lòng kiểm tra lại.';
            } else if (e.toString().contains('Network') || e.toString().contains('timeout')) {
              errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Nhập mật khẩu',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vui lòng nhập mật khẩu để liên kết vân tay. Mật khẩu sẽ được lưu an toàn trên thiết bị của bạn.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  labelStyle: GoogleFonts.inter(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.inter(),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: GoogleFonts.inter()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              child: Text('Xác nhận', style: GoogleFonts.inter()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hồ sơ',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _isLoading && !_isBiometricEnabled
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header thông tin user
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              auth.fullName?.substring(0, 1).toUpperCase() ??
                                  auth.username?.substring(0, 1).toUpperCase() ??
                                  '?',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.fullName ?? auth.username ?? 'Người dùng',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  auth.username ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (auth.roles.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    children: auth.roles.map((role) {
                                      return Chip(
                                        label: Text(
                                          role,
                                          style: GoogleFonts.inter(fontSize: 10),
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Phần Vân tay / Sinh trắc học
                  Text(
                    'Bảo mật',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Card vân tay
                  if (!_isBiometricSupported)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.fingerprint, size: 32, color: Colors.grey),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vân tay / Sinh trắc học',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Thiết bị không hỗ trợ',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_hasBiometrics)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.fingerprint, size: 32, color: Colors.grey),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vân tay / Sinh trắc học',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chưa đăng ký vân tay trên thiết bị',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _isBiometricEnabled
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _isBiometricEnabled,
                            onChanged: _isLoading ? null : (value) => _toggleBiometric(),
                            title: Text(
                              'Đăng nhập bằng vân tay',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _isBiometricEnabled
                                  ? 'Đã bật. Bạn có thể đăng nhập bằng vân tay'
                                  : 'Bật để đăng nhập nhanh bằng vân tay',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            secondary: Icon(
                              Icons.fingerprint,
                              size: 32,
                              color: _isBiometricEnabled
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          if (_availableBiometrics.isNotEmpty) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phương thức có sẵn:',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: _availableBiometrics.map((type) {
                                      return Chip(
                                        avatar: Text(_getBiometricTypeIcon(type)),
                                        label: Text(
                                          _getBiometricTypeName(type),
                                          style: GoogleFonts.inter(fontSize: 12),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Thông tin khác
                  Text(
                    'Thông tin tài khoản',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            'Tên đăng nhập',
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                          subtitle: Text(
                            auth.username ?? 'N/A',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (auth.fullName != null) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: Text(
                              'Họ và tên',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            subtitle: Text(
                              auth.fullName!,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (auth.apartmentCode != null && auth.apartmentCode!.isNotEmpty && auth.apartmentCode != '0') ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.apartment_outlined),
                            title: Text(
                              'Căn hộ',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            subtitle: Text(
                              auth.apartmentCode!,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

