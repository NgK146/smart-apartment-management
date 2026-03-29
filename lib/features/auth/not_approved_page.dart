import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/snackbar.dart';
import 'auth_provider.dart';

class NotApprovedPage extends StatefulWidget {
  final String username;
  final String password;
  const NotApprovedPage({super.key, required this.username, required this.password});

  @override
  State<NotApprovedPage> createState() => _NotApprovedPageState();
}

class _NotApprovedPageState extends State<NotApprovedPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF006769), Color(0xFF00A39A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Chờ duyệt tài khoản')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.hourglass_top, size: 48),
                  const SizedBox(height: 12),
                  const Text('Tài khoản của bạn đang chờ Ban quản lý duyệt.', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Username: ${widget.username}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : () async {
                      setState(()=>_loading=true);
                      try {
                        await context.read<AuthState>().login(widget.username, widget.password);
                        if (!mounted) return;
                        showSnack(context, 'Đăng nhập thành công');
                        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                      } catch (e) {
                        showSnack(context, e.toString(), error: true);
                      } finally { if (mounted) setState(()=>_loading=false); }
                    },
                    child: _loading
                        ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2))
                        : const Text('Thử đăng nhập lại'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Quay về đăng nhập')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
