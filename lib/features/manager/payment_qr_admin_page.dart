import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/ui/snackbar.dart';
import '../billing/invoices_service.dart';
import '../billing/invoice_model.dart';
import '../../core/services/payment_signalr_service.dart';

class PaymentQRAdminPage extends StatefulWidget {
  const PaymentQRAdminPage({super.key});

  @override
  State<PaymentQRAdminPage> createState() => _PaymentQRAdminPageState();
}

class _PaymentQRAdminPageState extends State<PaymentQRAdminPage> {
  final _invoicesService = InvoicesService();
  final _searchController = TextEditingController();
  
  List<InvoiceModel> _invoices = [];
  bool _loading = true;
  int _page = 1;
  String? _statusFilter;
  final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  StreamSubscription<Map<String, dynamic>>? _paymentSub;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _paymentSub = paymentSignalRService.paymentStream.listen((event) {
      final invoiceId = event['invoiceId']?.toString();
      if (invoiceId == null) return;
      final exists = _invoices.any((inv) => inv.id == invoiceId);
      if (exists) _loadInvoices(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paymentSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _page = 1;
        _invoices.clear();
      }
      final data = await _invoicesService.list(
        page: _page,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _invoices.addAll(data);
        _page++;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải hóa đơn: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generatePayOsQR(InvoiceModel invoice) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await api.dio.post(
        '/api/Payments/${invoice.id}/generate-payos-qr',
      );

      if (!mounted) return;
      Navigator.pop(context);

      final qrData = response.data['qrData'] as String;
      final paymentId = response.data['paymentId'] as String;
      final amount = (response.data['amount'] as num).toDouble();

      showDialog(
        context: context,
        builder: (context) => _QRCodeDialog(
          qrData: qrData,
          invoice: invoice,
          amount: amount,
          paymentId: paymentId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Lỗi khi tạo QR: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('QR Thanh Toán PayOS', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tất cả',
                    isSelected: _statusFilter == null,
                    onTap: () {
                      setState(() => _statusFilter = null);
                      _loadInvoices(refresh: true);
                    },
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Chưa thanh toán',
                    isSelected: _statusFilter == 'Unpaid',
                    onTap: () {
                      setState(() => _statusFilter = 'Unpaid');
                      _loadInvoices(refresh: true);
                    },
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'Quá hạn',
                    isSelected: _statusFilter == 'Overdue',
                    onTap: () {
                      setState(() => _statusFilter = 'Overdue');
                      _loadInvoices(refresh: true);
                    },
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading && _invoices.isEmpty
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Chưa có hóa đơn nào', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: _primaryColor,
                        onRefresh: () => _loadInvoices(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _invoices[index];
                            return _InvoiceCard(
                              invoice: invoice,
                              currencyFormatter: _currencyFormatter,
                              onGenerateQR: () => _generatePayOsQR(invoice),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
             boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý hóa đơn → QR Thanh Toán', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Tạo mã QR PayOS', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo căn hộ, năm/tháng...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: GoogleFonts.inter(color: Colors.black87),
              onChanged: (_) => _loadInvoices(refresh: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF009688) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF009688).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final NumberFormat currencyFormatter;
  final VoidCallback onGenerateQR;

  const _InvoiceCard({required this.invoice, required this.currencyFormatter, required this.onGenerateQR});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.deepPurple, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tháng ${invoice.month}/${invoice.year}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        if (invoice.apartmentCode != null)
                          Text('Căn hộ: ${invoice.apartmentCode}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: invoice.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invoice.statusText,
                    style: GoogleFonts.inter(color: invoice.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TỔNG TIỀN', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(invoice.totalAmount),
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                    ),
                  ],
                ),
                if (invoice.status == 'Unpaid' || invoice.status == 'Overdue')
                  FilledButton.icon(
                    onPressed: onGenerateQR,
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: Text('Tạo QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String qrData;
  final InvoiceModel invoice;
  final double amount;
  final String paymentId;

  const _QRCodeDialog({required this.qrData, required this.invoice, required this.amount, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('QR Code PayOS', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Hóa đơn ${invoice.month}/${invoice.year}', style: GoogleFonts.inter(color: Colors.grey[600])),
              if (invoice.apartmentCode != null)
                Text('CH: ${invoice.apartmentCode}', style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: QrImageView(
                  data: qrData,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Số tiền:', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                        Text(currencyFormatter.format(amount), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mã TT:', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                        Text(paymentId.substring(0, 8).toUpperCase(), style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Đóng', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[700])),
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
}
