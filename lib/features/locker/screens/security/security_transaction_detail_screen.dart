import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../services/locker_service.dart';
import '../../models/locker_transaction.dart';
import 'package:icitizen_app/features/auth/auth_provider.dart';
import 'package:icitizen_app/config/config_url.dart';

class SecurityTransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const SecurityTransactionDetailScreen({
    Key? key,
    required this.transactionId,
  }) : super(key: key);

  @override
  State<SecurityTransactionDetailScreen> createState() =>
      _SecurityTransactionDetailScreenState();
}

class _SecurityTransactionDetailScreenState
    extends State<SecurityTransactionDetailScreen> {
  LockerTransaction? _transaction;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _generatedOtp;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      final transactions = await lockerService.getSecurityTransactions();
      final transaction = transactions.firstWhere(
        (t) => t.id == widget.transactionId,
        orElse: () => throw Exception('Transaction not found'),
      );

      setState(() {
        _transaction = transaction;
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

  Future<void> _openCompartment() async {
    setState(() => _isProcessing = true);

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      await lockerService.openDrop(widget.transactionId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngăn tủ đã được mở. Vui lòng bỏ hàng vào.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmStored() async {
    setState(() => _isProcessing = true);

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      final otp = await lockerService.confirmStored(widget.transactionId);

      if (!mounted) return;

      setState(() => _generatedOtp = otp);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Đã lưu hàng'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mã OTP cho cư dân:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                child: Text(
                  otp,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: otp));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép OTP'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠️ Lưu ý: OTP này chỉ hiển thị 1 lần. Vui lòng ghi lại hoặc thông báo cho cư dân.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to transactions list
              },
              child: const Text('Hoàn thành'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết giao dịch'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết giao dịch'),
        ),
        body: const Center(child: Text('Không tìm thấy giao dịch')),
      );
    }

    final transaction = _transaction!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Badge
          Center(
            child: Chip(
              label: Text(
                transaction.status.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getStatusColor(transaction.status),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 24),

          // Compartment Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.meeting_room, size: 48, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    transaction.compartmentCode ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Căn hộ: ${transaction.apartmentCode ?? 'N/A'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin giao dịch',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _buildDetailRow('Mã GD', transaction.id),
                  _buildDetailRow('Ngày tạo', _formatDateTime(transaction.createdAtUtc)),
                  if (transaction.notes != null)
                    _buildDetailRow('Ghi chú', transaction.notes!),
                  if (transaction.dropTime != null)
                    _buildDetailRow('Thời gian lưu', _formatDateTime(transaction.dropTime!)),
                  if (transaction.pickupTime != null)
                    _buildDetailRow('Thời gian lấy', _formatDateTime(transaction.pickupTime!)),
                ],
              ),
            ),
          ),

          // Show OTP if generated
          if (_generatedOtp != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Mã OTP đã tạo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatedOtp!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          if (transaction.status == LockerTransactionStatus.receivedBySecurity) ...[
            FilledButton.icon(
              onPressed: _isProcessing ? null : _openCompartment,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open),
              label: const Text('Mở ngăn tủ'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _confirmStored,
              icon: const Icon(Icons.inventory),
              label: const Text('Xác nhận đã bỏ hàng'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // Convert UTC to Vietnam time (UTC+7)
    final vnTime = dt.add(const Duration(hours: 7));
    return '${vnTime.day}/${vnTime.month}/${vnTime.year} ${vnTime.hour}:${vnTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(LockerTransactionStatus status) {
    switch (status) {
      case LockerTransactionStatus.receivedBySecurity:
        return Colors.orange;
      case LockerTransactionStatus.stored:
        return Colors.blue;
      case LockerTransactionStatus.pickedUp:
        return Colors.green;
      case LockerTransactionStatus.expired:
        return Colors.red;
      case LockerTransactionStatus.cancelled:
        return Colors.grey;
    }
  }
}
