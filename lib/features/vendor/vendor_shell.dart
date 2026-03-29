import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'vendor_tasks_page.dart';
import '../marketplace/screens/store_dashboard_screen.dart';

class VendorShell extends StatefulWidget { const VendorShell({super.key}); @override State<VendorShell> createState()=>_VendorShellState(); }

class _VendorShellState extends State<VendorShell> {
  int _index = 0;
  late final List<Widget> _pages;
  late final List<NavigationDestination> _destinations;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthState>();
    final hasSellerRole = auth.roles.contains('Seller');
    
    if (hasSellerRole) {
      _pages = [const VendorTasksPage(), const StoreDashboardScreen(), const _Placeholder()];
      _destinations = const [
        NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Công việc'),
        NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Cửa hàng'),
        NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Báo cáo'),
      ];
    } else {
      _pages = [const VendorTasksPage(), const _Placeholder()];
      _destinations = const [
        NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Công việc'),
        NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Báo cáo'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICitizen – Nhà cung cấp'),
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
        destinations: _destinations,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override Widget build(BuildContext context) => const Center(child: Text('Báo cáo (đang phát triển)'));
}
