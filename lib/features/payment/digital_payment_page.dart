import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'models/digital_payment.dart';
import '../../core/api_client.dart';
import '../../core/services/payment_service.dart';

class DigitalPaymentPage extends StatefulWidget {
  const DigitalPaymentPage({super.key});

  @override
  State<DigitalPaymentPage> createState() => _DigitalPaymentPageState();
}

class _DigitalPaymentPageState extends State<DigitalPaymentPage> {
  int _selectedTab = 0; // 0: Wallet, 1: Payment Methods, 2: History, 3: Reminders

  DigitalWallet? _wallet;
  final List<PaymentMethod> _paymentMethods = [];
  final List<PaymentReminder> _reminders = [];
  final List<WalletTransaction> _transactions = [];
  late final PaymentService _paymentService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(api.dio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thanh toán số',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _TabChip(
              label: 'Ví',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _TabChip(
              label: 'Phương thức',
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
            _TabChip(
              label: 'Lịch sử',
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
            _TabChip(
              label: 'Nhắc nhở',
              isSelected: _selectedTab == 3,
              onTap: () => setState(() => _selectedTab = 3),
              badge: _reminders.where((r) => !r.isPaid).length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildWalletTab();
      case 1:
        return _buildPaymentMethodsTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildRemindersTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWalletTab() {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_wallet == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu ví điện tử',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Ví sẽ hiển thị khi bạn phát sinh giao dịch thực tế.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadWalletData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Wallet balance card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'Số dư ví',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatter.format(_wallet!.balance),
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTopUpDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nạp tiền'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.history),
                        label: const Text('Lịch sử'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.qr_code_scanner,
                    label: 'Quét QR',
                    color: theme.colorScheme.secondary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.receipt,
                    label: 'Hóa đơn',
                    color: theme.colorScheme.tertiary,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsTab() {
    if (_paymentMethods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Chưa có phương thức thanh toán nào. Hãy thêm phương thức khi cần thiết.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getPaymentMethodIcon(method.type),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(method.name),
            subtitle: method.accountNumber != null
                ? Text('${method.bankName} - ${method.accountNumber}')
                : null,
            trailing: method.isDefault
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Mặc định',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              if (method.qrCode != null) {
                _showQRCodeDialog(method);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final transactions = _transactions;

    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'Chưa có giao dịch',
          style: GoogleFonts.inter(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
        final isNegative = transaction.amount < 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isNegative ? Colors.red : Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isNegative ? Icons.arrow_upward : Icons.arrow_downward,
                color: isNegative ? Colors.red : Colors.green,
              ),
            ),
            title: Text(transaction.description),
            subtitle: Text(
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.timestamp),
            ),
            trailing: Text(
              '${isNegative ? '-' : '+'}${formatter.format(transaction.amount.abs())}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: isNegative ? Colors.red : Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemindersTab() {
    if (_reminders.isEmpty) {
      return Center(
        child: Text(
          'Chưa có nhắc nhở thanh toán',
          style: GoogleFonts.inter(color: Colors.grey.shade600),
        ),
      );
    }

    final unpaidReminders = _reminders.where((r) => !r.isPaid).toList();
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    if (unpaidReminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'Tất cả đã thanh toán',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unpaidReminders.length,
      itemBuilder: (context, index) {
        final reminder = unpaidReminders[index];
        final isOverdue = reminder.isOverdue;
        final isDueSoon = reminder.isDueSoon;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isOverdue
              ? Colors.red.shade50
              : isDueSoon
                  ? Colors.orange.shade50
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.description,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Quá hạn',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isDueSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sắp đến hạn',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatter.format(reminder.amount),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Hạn thanh toán: ${DateFormat('dd/MM/yyyy').format(reminder.dueDate)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Thanh toán ngay'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance;
      case PaymentMethodType.qrBank:
        return Icons.qr_code;
      case PaymentMethodType.creditCard:
        return Icons.credit_card;
      case PaymentMethodType.cash:
        return Icons.money;
    }
  }

  void _showTopUpDialog() {
    showDialog(
      context: context,
      builder: (context) => _TopUpDialog(
        paymentService: _paymentService,
        onTopUpSuccess: () {
          // Reload wallet data
          _loadWalletData();
        },
      ),
    );
  }

  Future<void> _loadWalletData() async {
    try {
      setState(() => _isLoading = true);
      final wallet = await _paymentService.getWallet();
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu ví: ${e.toString()}')),
        );
      }
    }
  }

  void _showQRCodeDialog(PaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => _QRCodeDialog(
        title: method.name,
        qrCode: method.qrCode!,
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopUpDialog extends StatefulWidget {
  final PaymentService paymentService;
  final VoidCallback? onTopUpSuccess;

  const _TopUpDialog({
    required this.paymentService,
    this.onTopUpSuccess,
  });

  @override
  State<_TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends State<_TopUpDialog> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nạp tiền vào ví',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Số tiền (VND)',
                  prefixText: '₫ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                keyboardType: TextInputType.number,
                enabled: !_isProcessing,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Bắt buộc';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) return 'Số tiền không hợp lệ';
                  if (amount < 10000) return 'Số tiền tối thiểu là 10,000 VND';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _handleTopUp,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Nạp tiền'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTopUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);
      final orderId = 'TOPUP_${DateTime.now().millisecondsSinceEpoch}';

      // Tạo QR code thanh toán qua Payment Gateway
      final result = await widget.paymentService.createGatewayQRCode(
        amount: amount,
        orderId: orderId,
        orderDescription: 'Nạp tiền vào ví',
      );

      if (mounted) {
        Navigator.pop(context);
        
        // Hiển thị QR code hoặc payment URL
        if (result.containsKey('qrCode') || result.containsKey('qrData')) {
          final qrData = result['qrCode'] ?? result['qrData'];
          showDialog(
            context: context,
            builder: (context) => _QRCodeDialog(
              title: 'Quét mã QR để thanh toán',
              qrCode: qrData.toString(),
            ),
          );
        } else if (result.containsKey('paymentUrl')) {
          // Mở payment URL trong browser hoặc WebView
          // Có thể sử dụng url_launcher hoặc webview_flutter
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo link thanh toán. Vui lòng kiểm tra email hoặc SMS.'),
              action: SnackBarAction(
                label: 'Mở link',
                onPressed: () {
                  // Implement open URL
                },
              ),
            ),
          );
        }

        widget.onTopUpSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo yêu cầu thanh toán: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String title;
  final String qrCode;

  const _QRCodeDialog({
    required this.title,
    required this.qrCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: qrCode,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }
}



