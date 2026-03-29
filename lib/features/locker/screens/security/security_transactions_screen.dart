import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/locker_service.dart';
import '../../models/locker_transaction.dart';
import '../../models/enums.dart';
import 'package:icitizen_app/features/auth/auth_provider.dart';
import 'package:icitizen_app/config/config_url.dart';
import 'security_transaction_detail_screen.dart';

class SecurityTransactionsScreen extends StatefulWidget {
  const SecurityTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<SecurityTransactionsScreen> createState() =>
      _SecurityTransactionsScreenState();
}

class _SecurityTransactionsScreenState
    extends State<SecurityTransactionsScreen> {
  List<LockerTransaction> _transactions = [];
  bool _isLoading = true;
  LockerTransactionStatus? _selectedStatus =
      LockerTransactionStatus.receivedBySecurity;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final lockerService = LockerService(
        baseUrl: AppConfig.apiBaseUrl,
        token: auth.token ?? '',
      );

      final transactions =
          await lockerService.getSecurityTransactions(status: _selectedStatus);

      setState(() {
        _transactions = transactions;
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
        title: const Text('Quản lý gói hàng'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              final auth = Provider.of<AuthState>(context, listen: false);
              auth.logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'Chờ lưu',
                    LockerTransactionStatus.receivedBySecurity,
                    Icons.inbox,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Đã lưu',
                    LockerTransactionStatus.stored,
                    Icons.inventory,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Đã lấy',
                    LockerTransactionStatus.pickedUp,
                    Icons.check_circle,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Tất cả',
                    null,
                    Icons.list,
                  ),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có giao dịch',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/locker/receive-package');
          _loadTransactions();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nhận hàng mới'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    LockerTransactionStatus? status,
    IconData icon,
  ) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _loadTransactions();
      },
      selectedColor: Colors.blue.shade100,
    );
  }

  Widget _buildTransactionCard(LockerTransaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SecurityTransactionDetailScreen(
                transactionId: transaction.id,
              ),
            ),
          );
          _loadTransactions();
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Căn hộ ${transaction.apartmentCode ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ngăn: ${transaction.compartmentCode ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      transaction.status.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: _getStatusColor(transaction.status),
                    labelStyle: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (transaction.notes != null) ...[
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
                          transaction.notes!,
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
              const SizedBox(height: 8),
              Text(
                _formatDateTime(transaction.createdAtUtc),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    // Convert UTC to Vietnam time (GMT+7)
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
