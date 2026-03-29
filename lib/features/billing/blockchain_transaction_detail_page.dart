import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/ui/snackbar.dart';
import 'blockchain_service.dart';
import 'blockchain_transaction_detail_model.dart';
import 'invoice_detail_page.dart';

class BlockchainTransactionDetailPage extends StatefulWidget {
  final String transactionHash;

  const BlockchainTransactionDetailPage({
    super.key,
    required this.transactionHash,
  });

  @override
  State<BlockchainTransactionDetailPage> createState() => _BlockchainTransactionDetailPageState();
}

class _BlockchainTransactionDetailPageState extends State<BlockchainTransactionDetailPage>
    with SingleTickerProviderStateMixin {
  late BlockchainService _blockchainService;
  BlockchainTransactionDetail? _detail;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool? _isVerified;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _blockchainService = BlockchainService(ApiClient());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadTransactionDetail();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactionDetail() async {
    setState(() => _isLoading = true);
    
    try {
      final detail = await _blockchainService.getTransactionDetail(widget.transactionHash);
      
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnack(context, 'Không thể tải chi tiết giao dịch: $e', error: true);
      }
    }
  }

  Future<void> _verifyTransaction() async {
    setState(() => _isVerifying = true);
    
    try {
      final verified = await _blockchainService.verifyTransaction(widget.transactionHash);
      
      setState(() {
        _isVerified = verified;
        _isVerifying = false;
      });
      
      if (mounted) {
        if (verified) {
          showSnack(context, '✓ Giao dịch đã được xác minh trên blockchain');
        } else {
          showSnack(context, '✗ Không thể xác minh giao dịch', error: true);
        }
      }
    } catch (e) {
      setState(() => _isVerifying = false);
      if (mounted) {
        showSnack(context, 'Lỗi khi xác minh: $e', error: true);
      }
    }
  }

  Future<void> _openBlockchainExplorer() async {
    if (_detail == null) return;
    
    final url = Uri.parse(_detail!.explorerUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showSnack(context, 'Không thể mở Blockchain Explorer', error: true);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    showSnack(context, 'Đã copy $label vào clipboard');
  }

  void _shareTransactionHash() {
    // Simple share implementation
    Clipboard.setData(ClipboardData(text: widget.transactionHash));
    showSnack(context, 'Đã copy transaction hash để chia sẻ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Blockchain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareTransactionHash,
            tooltip: 'Chia sẻ',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? _buildErrorState(theme)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(theme),
                          const SizedBox(height: 16),
                          _buildTransactionInfoCard(theme),
                          const SizedBox(height: 16),
                          _buildPaymentInfoCard(theme),
                          const SizedBox(height: 16),
                          _buildVerificationCard(theme),
                          const SizedBox(height: 16),
                          _buildActionButtons(theme),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _detail!.statusText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _detail!.formattedAmount,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Thông tin giao dịch',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              theme,
              'Transaction Hash',
              _detail!.transactionHash,
              onTap: () => _copyToClipboard(_detail!.transactionHash, 'transaction hash'),
              showCopy: true,
            ),
            const SizedBox(height: 12),
            if (_detail!.blockNumber != null)
              _buildInfoRow(
                theme,
                'Block Number',
                '#${_detail!.blockNumber}',
              ),
            if (_detail!.blockNumber != null) const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Timestamp',
              _detail!.formattedTimestamp,
            ),
            const SizedBox(height: 12),
            if (_detail!.gasUsed != null)
              _buildInfoRow(
                theme,
                'Gas Used',
                _detail!.gasUsed!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Thông tin thanh toán',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              theme,
              'Mã hóa đơn',
              _detail!.invoiceId,
              onTap: () {
                // Navigate to invoice detail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoiceDetailPage(invoiceId: _detail!.invoiceId),
                  ),
                );
              },
              showLink: true,
            ),
            const SizedBox(height: 12),
            if (_detail!.apartmentNumber != null)
              _buildInfoRow(
                theme,
                'Căn hộ',
                _detail!.apartmentNumber!,
              ),
            if (_detail!.apartmentNumber != null) const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Số tiền',
              _detail!.formattedAmount,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Phương thức',
              _detail!.methodText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Xác minh Blockchain',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_isVerified != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isVerified!
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isVerified!
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isVerified! ? Icons.check_circle : Icons.error,
                      color: _isVerified! ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isVerified!
                            ? 'Giao dịch đã được xác minh thành công'
                            : 'Không thể xác minh giao dịch',
                        style: TextStyle(
                          color: _isVerified! ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _verifyTransaction,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified),
                label: Text(_isVerifying ? 'Đang xác minh...' : 'Xác minh trên Blockchain'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openBlockchainExplorer,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Xem trên Blockchain Explorer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value, {
    VoidCallback? onTap,
    bool showCopy = false,
    bool showLink = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: showCopy ? 'monospace' : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (showCopy || showLink) const SizedBox(width: 8),
                  if (showCopy)
                    Icon(Icons.copy, size: 16, color: theme.primaryColor),
                  if (showLink)
                    Icon(Icons.arrow_forward, size: 16, color: theme.primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy giao dịch',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }
}
