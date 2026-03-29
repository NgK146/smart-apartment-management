import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'incident_page.dart';
import 'security_complaints_page.dart';

class SecurityShell extends StatefulWidget { const SecurityShell({super.key}); @override State<SecurityShell> createState()=>_SecurityShellState(); }

class _SecurityShellState extends State<SecurityShell> {
  int _index = 0;
  final _pages = const [SecurityComplaintsPage(), _Placeholder(), _LockerPlaceholder()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICitizen – Bảo vệ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthState>().logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index, onDestinationSelected: (i)=> setState(()=>_index=i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.report_gmailerrorred_outlined), selectedIcon: Icon(Icons.report), label: 'Phản ánh'),
          NavigationDestination(icon: Icon(Icons.add_alert_outlined), selectedIcon: Icon(Icons.add_alert), label: 'Sự cố'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Locker'),
        ],
      ),
      floatingActionButton: _index == 1 ? FloatingActionButton.extended(
        onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const IncidentPage())),
        icon: const Icon(Icons.add),
        label: const Text('Ghi nhận sự cố'),
      ) : null,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override Widget build(BuildContext context) => const Center(child: Text('Nhấn + để ghi nhận sự cố'));
}

class _LockerPlaceholder extends StatefulWidget {
  const _LockerPlaceholder();
  @override State<_LockerPlaceholder> createState() => _LockerPlaceholderState();
}

class _LockerPlaceholderState extends State<_LockerPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/locker/security/transactions');
    });
  }

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
