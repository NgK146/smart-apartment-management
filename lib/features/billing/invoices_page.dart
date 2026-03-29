import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import 'invoice_model.dart';
import 'invoices_service.dart';
import 'invoice_detail_page.dart';
import 'vn_pay_payment_page.dart';
import '../../core/services/payment_signalr_service.dart';

class InvoicesPage extends StatefulWidget {
  final String? highlightInvoiceId;
  
  const InvoicesPage({super.key, this.highlightInvoiceId});
  
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _svc = InvoicesService(); final _items = <InvoiceModel>[]; bool _loading=false; int _page=1; bool _done=false;
  final _sc = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _paymentSub;

  // Màu chủ đạo
  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override void initState(){
    super.initState();
    _load();
    _sc.addListener(()=> _onScroll());
    _paymentSub = paymentSignalRService.paymentStream.listen((event) {
      final invoiceId = event['invoiceId']?.toString();
      final status = event['status']?.toString();
      if (invoiceId == null) return;
      final hasInvoice = _items.any((inv) => inv.id == invoiceId);
      // Refresh nếu có invoice trong danh sách hoặc nếu thanh toán thành công
      if (hasInvoice || status?.toLowerCase() == 'success') {
        _load(refresh: true);
      }
    });
    
    // Nếu có highlightInvoiceId, mở invoice detail sau khi load
    if (widget.highlightInvoiceId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _openInvoiceIfFound(widget.highlightInvoiceId!);
      });
    }
  }
  void _onScroll(){ if(_sc.position.pixels >= _sc.position.maxScrollExtent-100 && !_loading && !_done) _load(); }

  @override
  void dispose() {
    _paymentSub?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh=false}) async {
    setState(()=>_loading=true);
    try {
      if(refresh){ _page=1; _done=false; _items.clear(); }
      // Sử dụng getMyInvoices cho cư dân
      final data = await _svc.getMyInvoices(page:_page);
      setState((){ _items.addAll(data); if(data.length<20) _done=true; _page++; });
    } catch(e){ 
      if (mounted) showSnack(context, 'Lỗi tải hoá đơn: $e', error: true); 
    }
    finally { 
      if (mounted) setState(()=>_loading=false); 
    }
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Header
          _buildHeader(),

          // 2. Danh sách hóa đơn
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('Chưa có hoá đơn', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: ()=>_load(refresh:true),
                    color: theme.colorScheme.primary,
                    child: ListView.builder(
                      controller: _sc,
                      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 80),
                      itemCount: _items.length + 1,
                      itemBuilder: (c,i){
                        if(i==_items.length) return Padding(padding: const EdgeInsets.all(16), child: Center(child:_loading?const CircularProgressIndicator():const SizedBox.shrink()));
                        final inv = _items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: inv.id)),
                              );
                              // Refresh sau khi quay lại từ trang chi tiết
                              if (mounted) {
                                await Future.delayed(const Duration(milliseconds: 300));
                                _load(refresh: true);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Hóa đơn tháng ${inv.month}/${inv.year}',
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: inv.statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: inv.statusColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          inv.statusText,
                                          style: TextStyle(color: inv.statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hạn thanh toán: ${inv.dueDate.day}/${inv.dueDate.month}/${inv.dueDate.year}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (inv.isOverdue) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Quá hạn',
                                            style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Tổng cộng: ${inv.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\\d{3})+(?!\\d))'), (Match m) => '${m[1]},')} đ',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: _primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (inv.status == 'Unpaid' || inv.status == 'PartiallyPaid')
                                        Flexible(
                                          child: FilledButton.icon(
                                            onPressed: () => _handlePayment(inv),
                                            icon: const Icon(Icons.payment, size: 18),
                                            label: const Text('Thanh toán', style: TextStyle(fontSize: 12)),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _primaryColor,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 45, 16, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [
                const Color(0xFF1A237E),
                const Color(0xFF4A148C),
                const Color(0xFF006064),
              ]
            : [
                const Color(0xFF0091EA),
                const Color(0xFF00B8D4),
                const Color(0xFF00BFA5),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Quay lại',
            ),
            const SizedBox(height: 12),
            Text(
              'Dịch vụ cư dân', 
              style: GoogleFonts.montserrat(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hoá đơn', 
              style: GoogleFonts.montserrat(
                color: Colors.white, 
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${_items.length} hoá đơn', 
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment(InvoiceModel inv) async {
    try {
      // Tạo link thanh toán PayOS
      final result = await _svc.createPayOsLink(inv.id);
      final paymentUrl = (result['checkoutUrl'] ?? result['paymentUrl']) as String?;
      final paymentId = result['paymentId']?.toString();
      
      if (paymentUrl != null && mounted) {
        // Mở trang thanh toán PayOS trong app
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VnPayPaymentUrlPage(
              paymentUrl: paymentUrl,
              paymentId: paymentId,
              invoiceId: inv.id,
              title: 'Thanh toán PayOS',
            ),
          ),
        );
        
        // Refresh danh sách sau khi thanh toán
        if (mounted && paymentResult == true) {
          await Future.delayed(const Duration(milliseconds: 500));
          _load(refresh: true);
        }
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tạo link thanh toán: $e', error: true);
    }
  }
  
  /// Mở invoice detail nếu tìm thấy invoice bằng ID
  void _openInvoiceIfFound(String invoiceId) {
    final invoice = _items.firstWhere(
      (inv) => inv.id == invoiceId,
      orElse: () => _items.isNotEmpty ? _items.first : null as InvoiceModel,
    );
    
    if (invoice != null && invoice.id == invoiceId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: invoice.id),
        ),
      ).then((_) {
        if (mounted) _load(refresh: true);
      });
    }
  }
}
