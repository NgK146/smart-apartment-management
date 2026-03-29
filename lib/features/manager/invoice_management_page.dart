import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../billing/invoices_service.dart';
import '../billing/billing_service.dart';
import '../billing/invoice_model.dart';

class InvoiceManagementPage extends StatefulWidget {
  const InvoiceManagementPage({super.key});

  @override
  State<InvoiceManagementPage> createState() => _InvoiceManagementPageState();
}

class _InvoiceManagementPageState extends State<InvoiceManagementPage> with SingleTickerProviderStateMixin {
  final _invoicesSvc = InvoicesService();
  final _billingSvc = BillingService();
  final _searchController = TextEditingController();
  
  List<InvoiceModel> _items = [];
  bool _loading = true;
  int _page = 1;
  String? _statusFilter;
  int? _monthFilter;
  int? _yearFilter;
  
  late TabController _tabController;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          _statusFilter = null; // Tất cả
          break;
        case 1:
          _statusFilter = 'Unpaid';
          break;
        case 2:
          _statusFilter = 'Paid';
          break;
        case 3:
          _statusFilter = 'Overdue';
          break;
      }
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _page = 1;
        _items.clear();
      }
      final data = await _invoicesSvc.list(
        page: _page,
        status: _statusFilter,
        month: _monthFilter,
        year: _yearFilter,
        // search: _searchController.text.isNotEmpty ? _searchController.text : null, // Assuming service supports search
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _page++;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải hóa đơn: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateManagementFeeInvoices() async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final dueDate = DateTime(year, month, 10);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Tạo hóa đơn phí quản lý cho tháng $month/$year?\n'
          'Hạn thanh toán: ${DateFormat('dd/MM/yyyy').format(dueDate)} (từ ngày 1 đến 10).',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Tạo hóa đơn', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _billingSvc.generateManagementFees(
        month: month,
        year: year,
      );

      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      final count = result['count'] as int? ?? result['Count'] as int? ?? 0;
      showSnack(context, 'Đã tạo $count hóa đơn thành công');
      _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog nếu có
      showSnack(context, 'Lỗi tạo hóa đơn: $e', error: true);
    }
  }

  Future<void> _generateUtilityInvoices() async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    // Hạn thanh toán: ngày 5 của tháng sau (có thể điều chỉnh sau nếu cần)
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final dueDate = DateTime(nextYear, nextMonth, 5);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tạo hóa đơn Điện/Nước', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Tạo hóa đơn Điện/Nước cho tháng $month/$year?\n'
          'Hạn thanh toán: ${DateFormat('dd/MM/yyyy').format(dueDate)}.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Tạo hóa đơn', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _billingSvc.generateInvoices(
        month: month,
        year: year,
        dueDate: dueDate,
      );

      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      final count = result['Count'] as int? ?? result['count'] as int? ?? 0;
      showSnack(context, 'Đã tạo $count hóa đơn Điện/Nước thành công');
      _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog nếu có
      showSnack(context, 'Lỗi tạo hóa đơn: $e', error: true);
    }
  }

  Future<void> _deleteAllCurrentInvoices() async {
    if (_items.isEmpty) {
      if (mounted) showSnack(context, 'Không có hóa đơn nào để xoá');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xoá hoá đơn', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          'Bạn muốn xoá ${_items.length} hoá đơn đang hiển thị?\n'
          'Hành động này không thể hoàn tác, chỉ nên dùng để xoá dữ liệu test/ảo.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Xoá tất cả', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      for (final inv in _items) {
        await _invoicesSvc.delete(inv.id);
      }

      if (!mounted) return;
      Navigator.pop(context); // đóng loading
      showSnack(context, 'Đã xoá toàn bộ hoá đơn đang hiển thị');
      _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Lỗi xoá hoá đơn: $e', error: true);
    }
  }

  Future<void> _confirmManualPayment(InvoiceModel invoice) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận thanh toán', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Xác nhận cư dân đã thanh toán hóa đơn tháng ${invoice.month}/${invoice.year}?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Xác nhận', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _invoicesSvc.confirmManualPayment(invoice.id);
      if (!mounted) return;
      showSnack(context, 'Đã xác nhận thanh toán');
      _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi: $e', error: true);
    }
  }

  void _showInvoiceDetailBottomSheet(InvoiceModel invoice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hóa đơn ${invoice.month}/${invoice.year}',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Căn hộ: ${invoice.apartmentCode ?? "N/A"}',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: invoice.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: invoice.statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      invoice.statusText,
                      style: GoogleFonts.inter(
                        color: invoice.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DetailRow(icon: Icons.calendar_today, label: 'Kỳ hạn', value: DateFormat('dd/MM/yyyy').format(invoice.dueDate)),
              _DetailRow(icon: Icons.receipt, label: 'Loại phí', value: 'Điện/Nước/QL'), // Adjust as needed if type is available
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng tiền:',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  Text(
                    _currencyFormatter.format(invoice.totalAmount),
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text('Đóng', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87)),
                    ),
                  ),
                  if (invoice.status == 'Unpaid') ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmManualPayment(invoice);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Đã nhận tiền', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Increased bottom padding for search bar + tabs
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                     IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text('Admin', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                        onPressed: _deleteAllCurrentInvoices,
                        tooltip: 'Xoá danh sách hiện tại',
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('Quản lý Hóa đơn', style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // Modern TabBar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelColor: _primaryColor,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                      unselectedLabelColor: Colors.white70,
                      unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Tất cả'),
                        Tab(text: 'Chưa TT'),
                        Tab(text: 'Đã TT'),
                        Tab(text: 'Quá hạn'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating Search Bar & Filter
        Positioned(
          bottom: -40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm hóa đơn...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _load(refresh: true);
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        style: GoogleFonts.inter(),
                        onSubmitted: (_) => _load(refresh: true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
               Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _ActionButton(
                        icon: Icons.receipt_long,
                        label: 'Tạo phí QL',
                        onPressed: _generateManagementFeeInvoices
                    ),
                    _ActionButton(
                        icon: Icons.bolt,
                        label: 'Tạo Điện/Nước',
                        onPressed: _generateUtilityInvoices
                    ),
                  ],
               ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 50), // Spacer for floating header
          Expanded(
            child: _loading && _items.isEmpty
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Chưa có hóa đơn nào', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              color: _primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loading ? const CircularProgressIndicator() : const SizedBox.shrink(),
                      ),
                    );
                  }
                  return _InvoiceCard(
                    invoice: _items[index],
                    onTap: () => _showInvoiceDetailBottomSheet(_items[index]),
                    onQuickPayment: (inv) => _confirmManualPayment(inv),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF009688),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Color(0xFF009688), width: 1),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;
  final Function(InvoiceModel) onQuickPayment;

  const _InvoiceCard({required this.invoice, required this.onTap, required this.onQuickPayment});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Tháng ${invoice.month}/${invoice.year}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: invoice.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        invoice.statusText,
                        style: GoogleFonts.inter(
                          color: invoice.statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.apartment, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      invoice.apartmentCode ?? 'Unknown',
                      style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM').format(invoice.dueDate),
                      style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currencyFormatter.format(invoice.totalAmount),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF009688),
                      ),
                    ),
                    if (invoice.status == 'Unpaid')
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          onPressed: () => onQuickPayment(invoice),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Đã thu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }
}
