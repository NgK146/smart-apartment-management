import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../services/locker_service.dart';
import '../../models/locker_transaction.dart';
import 'package:icitizen_app/features/auth/auth_provider.dart';
import 'package:icitizen_app/config/config_url.dart';

class ResidentPackagesScreen extends StatefulWidget {
  const ResidentPackagesScreen({Key? key}) : super(key: key);

  @override
  State<ResidentPackagesScreen> createState() =>
      _ResidentPackagesScreenState();
}

class _ResidentPackagesScreenState extends State<ResidentPackagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LockerTransaction> _storedPackages = [];
  List<LockerTransaction> _historyPackages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPackages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      final stored = await lockerService.getMyTransactions(
        status: LockerTransactionStatus.stored,
      );
      
      final pickedUp = await lockerService.getMyTransactions(
        status: LockerTransactionStatus.pickedUp,
      );

      setState(() {
        _storedPackages = stored;
        _historyPackages = pickedUp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói hàng của tôi'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: Badge(
                label: Text(_storedPackages.length.toString()),
                isLabelVisible: _storedPackages.isNotEmpty,
                child: const Icon(Icons.inventory),
              ),
              text: 'Chờ lấy',
            ),
            const Tab(
              icon: Icon(Icons.history),
              text: 'Lịch sử',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPackages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Stored packages
                _buildPackagesList(_storedPackages, isStored: true),
                // History
                _buildPackagesList(_historyPackages, isStored: false),
              ],
            ),
    );
  }

  Widget _buildPackagesList(
    List<LockerTransaction> packages, {
    required bool isStored,
  }) {
    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isStored ? Icons.inbox : Icons.history,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isStored ? 'Không có gói hàng mới' : 'Chưa có lịch sử',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPackages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final package = packages[index];
          return _buildPackageCard(package, isStored: isStored);
        },
      ),
    );
  }

  Widget _buildPackageCard(
    LockerTransaction package, {
    required bool isStored,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isStored) {
            _showPickupDialog(package);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isStored
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isStored ? Icons.inventory_2 : Icons.check_circle,
                      color: isStored ? Colors.green.shade700 : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.meeting_room, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              package.compartmentCode ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              isStored
                                  ? 'Lưu lúc: ${_formatDateTime(package.dropTime!)}'
                                  : 'Lấy lúc: ${_formatDateTime(package.pickupTime!)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (package.notes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          package.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isStored) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showPickupDialog(package),
                        icon: const Icon(Icons.input),
                        label: const Text('Nhập OTP lấy hàng'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPickupDialog(LockerTransaction package) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pin, color: Colors.green),
            SizedBox(width: 8),
            Text('Nhập mã OTP'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập mã OTP 6 số để lấy hàng từ ngăn ${package.compartmentCode}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(
                labelText: 'Mã OTP',
                hintText: '000000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (otpController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập đủ 6 số OTP'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _verifyAndPickup(package.id, otpController.text);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyAndPickup(String transactionId, String otp) async {
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      // Verify OTP
      await lockerService.verifyPickup(
        transactionId: transactionId,
        otp: otp,
      );

      if (!mounted) return;

      // Show success and ask to confirm pickup
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('OTP hợp lệ!'),
            ],
          ),
          content: const Text(
            'Vui lòng đến ngăn tủ lấy hàng, sau đó xác nhận đã lấy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đã lấy hàng'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await lockerService.confirmPicked(transactionId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận lấy hàng thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadPackages();
      }
    } catch (e) {
      if (!mounted) return;

      // Show beautiful error dialog instead of SnackBar
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: const Text('Mã OTP không đúng'),
              ),
            ],
          ),
          content: const Text(
            'Vui lòng kiểm tra lại mã OTP và nhập lại.\n\nMã OTP có 6 chữ số và có hiệu lực trong 24 giờ.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Nhập lại'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    // Convert UTC to Vietnam time (UTC+7)
    final vnTime = dt.add(const Duration(hours: 7));
    return '${vnTime.day}/${vnTime.month}/${vnTime.year} ${vnTime.hour}:${vnTime.minute.toString().padLeft(2, '0')}';
  }
}
