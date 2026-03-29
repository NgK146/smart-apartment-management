import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/ui/snackbar.dart';
import 'invoice_model.dart';
import 'invoices_service.dart';
import 'payos_payment_page.dart';
import 'blockchain_transaction_detail_page.dart';


class InvoiceDetailPage extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  final _svc = InvoicesService();
  InvoiceModel? _invoice;
  bool _loading = true;
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _loading = true);
    try {
      _invoice = await _svc.get(widget.invoiceId);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải hóa đơn: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePayment() async {
    if (_invoice == null) return;
    
    showSnack(context, '⏳ Đang tạo liên kết thanh toán...', error: false);
    
    try {
      // Tạo payment cho invoice (giống amenity booking)
      final paymentResponse = await api.dio.post(
        '/api/Invoices/${_invoice!.id}/payos-payment',
      );
      
      final paymentId = paymentResponse.data['paymentId'] as String;
      final checkoutUrl = paymentResponse.data['checkoutUrl'] as String;
      
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayOsPaymentPage(
              invoice: _invoice!,
              paymentId: paymentId,
              checkoutUrl: checkoutUrl,
            ),
          ),
        );
        
        if (result == true && mounted) {
          // Thanh toán thành công, đợi backend cập nhật và retry nếu cần
          showSnack(context, '⏳ Đang cập nhật trạng thái thanh toán...', error: false);
          
          // Retry lên đến 5 lần với delay 1 giây mỗi lần
          bool statusUpdated = false;
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(seconds: 1));
            await _loadInvoice();
            if (_invoice?.status == 'Paid') {
              statusUpdated = true;
              break;
            }
          }
          
          if (mounted) {
            if (statusUpdated) {
              showSnack(context, '✅ Thanh toán thành công!', error: false);
            } else {
              showSnack(context, '⚠️ Đã thanh toán. Vui lòng đợi hệ thống cập nhật.', error: false);
            }
          }
        } else if (result == false && mounted) {
          // Thanh toán thất bại
          showSnack(context, 'Thanh toán thất bại. Vui lòng thử lại.', error: true);
        }
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi thanh toán: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Ensure result is true to refresh invoice list when going back
          debugPrint('📱 Invoice detail page popped with result: $result');
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Column(
          children: [
            // Header
            _buildHeader(theme),

            // Nội dung
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoice == null
                      ? const Center(child: Text('Không tìm thấy hóa đơn'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thông tin chung
                              _buildInfoCard(theme),
                              const SizedBox(height: 16),

                              // Thông tin tiện ích (nếu là invoice từ amenity booking)
                              if (_invoice!.type == 'Service' && _invoice!.lines.any((line) => 
                                  line.feeName.toLowerCase().contains('tiện ích') || 
                                  line.description.toLowerCase().contains('đặt tiện ích')))
                                _buildAmenityInfoCard(theme),
                              if (_invoice!.type == 'Service' && _invoice!.lines.any((line) => 
                                  line.feeName.toLowerCase().contains('tiện ích') || 
                                  line.description.toLowerCase().contains('đặt tiện ích')))
                                const SizedBox(height: 16),

                              // Blockchain verification section (nếu đã thanh toán và có hash)
                              if (_invoice!.hasBlockchainRecord)
                                _buildBlockchainVerificationCard(theme),
                              if (_invoice!.hasBlockchainRecord)
                                const SizedBox(height: 16),

                              // Chi tiết các khoản phí
                              Text(
                                'Chi tiết các khoản phí',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              ..._invoice!.lines.map((line) => _buildLineCard(theme, line)),
                              const SizedBox(height: 16),

                              // Tổng cộng
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tổng cộng:',
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _currencyFormatter.format(_invoice!.totalAmount),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: _invoice != null && 
            (_invoice!.status == 'Unpaid' || _invoice!.status == 'PartiallyPaid') &&
            _invoice!.type != 'Service' // Ẩn nút thanh toán cho hóa đơn tiện ích (đã thanh toán lúc đặt)
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _handlePayment,
                      icon: const Icon(Icons.payment),
                      label: const Text('Thanh toán ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 60),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                tooltip: 'Quay lại',
              ),
              const SizedBox(height: 8),
              const Text('Dịch vụ cư dân', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                _invoice != null ? 'Hóa đơn tháng ${_invoice!.month}/${_invoice!.year}' : 'Chi tiết hóa đơn',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    if (_invoice == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thông tin hóa đơn',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _invoice!.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _invoice!.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _invoice!.statusText,
                  style: TextStyle(color: _invoice!.statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(theme, Icons.home, 'Căn hộ', _invoice!.apartmentCode ?? 'N/A'),
          _buildInfoRow(theme, Icons.calendar_today, 'Kỳ thanh toán', 
              '${DateFormat('dd/MM/yyyy').format(_invoice!.periodStart)} - ${DateFormat('dd/MM/yyyy').format(_invoice!.periodEnd)}'),
          _buildInfoRow(theme, Icons.event, 'Hạn thanh toán', 
              DateFormat('dd/MM/yyyy').format(_invoice!.dueDate)),
          if (_invoice!.isOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Hóa đơn đã quá hạn thanh toán',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCard(ThemeData theme, InvoiceLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.feeName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (line.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      line.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              _currencyFormatter.format(line.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityInfoCard(ThemeData theme) {
    // Tìm line có thông tin tiện ích
    final amenityLine = _invoice!.lines.firstWhere(
      (line) => line.feeName.toLowerCase().contains('tiện ích') || 
                line.description.toLowerCase().contains('đặt tiện ích'),
      orElse: () => _invoice!.lines.first,
    );

    // Parse thông tin từ description: "Đặt tiện ích {name} ({start} - {end})"
    final description = amenityLine.description;
    String amenityName = amenityLine.feeName;
    String timeRange = '';
    
    // Tìm thời gian trong description
    final timeMatch = RegExp(r'\((\d{2}/\d{2}\s+\d{2}:\d{2})\s+-\s+(\d{2}:\d{2})\)').firstMatch(description);
    if (timeMatch != null) {
      timeRange = '${timeMatch.group(1)} - ${timeMatch.group(2)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thông tin tiện ích',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAmenityInfoRow(theme, Icons.place, 'Tên tiện ích', amenityName),
          if (timeRange.isNotEmpty)
            _buildAmenityInfoRow(theme, Icons.access_time, 'Thời gian sử dụng', timeRange),
          _buildAmenityInfoRow(theme, Icons.attach_money, 'Giá tiền', _currencyFormatter.format(amenityLine.amount)),
        ],
      ),
    );
  }

  Widget _buildAmenityInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockchainVerificationCard(ThemeData theme) {
    if (_invoice == null || !_invoice!.hasBlockchainRecord) {
      return const SizedBox.shrink();
    }

    // Shorten hash for display
    final hash = _invoice!.blockchainTxHash!;
    final shortHash = hash.length > 16
        ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}'
        : hash;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác minh Blockchain',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      'Giao dịch đã được ghi lên blockchain',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Đã xác minh',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.tag, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Transaction Hash:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shortHash,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hash));
                    showSnack(context, 'Đã copy hash vào clipboard');
                  },
                  tooltip: 'Copy hash',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlockchainTransactionDetailPage(
                      transactionHash: hash,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Xem chi tiết Blockchain'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

