import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/ui/snackbar.dart';

class QRManagementPage extends StatefulWidget {
  const QRManagementPage({super.key});

  @override
  State<QRManagementPage> createState() => _QRManagementPageState();
}

class _QRManagementPageState extends State<QRManagementPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  String? _statusFilter;
  final _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (refresh) {
        _page = 1;
        _payments.clear();
      }
      
      // Load stats
      final statsResponse = await api.dio.get('/api/Payments/admin/qr-payments/stats');
      if (mounted) {
        setState(() => _stats = Map<String, dynamic>.from(statsResponse.data));
      }

      // Load payments
      await _loadPayments();
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải dữ liệu: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _loadingMore = true);
    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'pageSize': 20,
      };
      if (_statusFilter != null) queryParams['status'] = _statusFilter;
      if (_searchController.text.isNotEmpty) queryParams['search'] = _searchController.text;

      final response = await api.dio.get(
        '/api/Payments/admin/qr-payments',
        queryParameters: queryParams,
      );

      if (!mounted) return;
      final data = Map<String, dynamic>.from(response.data);
      final items = (data['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() {
        if (_page == 1) {
          _payments = items;
        } else {
          _payments.addAll(items);
        }
        _page++;
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi tải danh sách: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    await _loadPayments();
  }

  void _applyFilter() {
    _page = 1;
    _payments.clear();
    _loadData();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return 'Đã thanh toán';
      case 'pending':
        return 'Chờ thanh toán';
      case 'failed':
        return 'Thất bại';
      default:
        return status;
    }
  }

  Future<void> _showQRCode(Map<String, dynamic> payment) async {
    // Generate QR URL từ payment
    try {
      final invoiceId = payment['invoiceId']?.toString();
      if (invoiceId == null) {
        showSnack(context, 'Không tìm thấy invoice', error: true);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await api.dio.post('/api/Payments/$invoiceId/generate-payos-qr');

      if (!mounted) return;
      Navigator.pop(context); // Đóng loading

      final qrData = response.data['qrData'] as String;
      final amount = (response.data['amount'] as num).toDouble();
      final invoiceInfo = response.data['invoiceInfo'] as Map<String, dynamic>?;

      showDialog(
        context: context,
        builder: (context) => _QRCodeDialog(
          qrData: qrData,
          payment: payment,
          amount: amount,
          invoiceInfo: invoiceInfo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading nếu có
      showSnack(context, 'Lỗi khi tạo QR: $e', error: true);
    }
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
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
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Quản lý QR',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                   const SizedBox(height: 5),
                  Text(
                    'Theo dõi thanh toán',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: 16,
          right: 16,
          child: Column(
            children: [
               Container(
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
                    hintText: 'Tìm theo căn hộ, mã giao dịch...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  style: GoogleFonts.inter(),
                  onSubmitted: (_) => _applyFilter(),
                ),
               ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip('Tất cả', null),
                      _buildFilterChip('Chờ thanh toán', 'Pending'),
                      _buildFilterChip('Đã thanh toán', 'Success'),
                      _buildFilterChip('Thất bại', 'Failed'),
                    ],
                  ),
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
          const SizedBox(height: 60), // Space for floating search

          // Stats Cards - Only visible if we have data, placed in scrollable area or here?
          // Let's put it in the scrollable area or just below search
          if (_stats != null) _buildStatsCards(),
          
          // List
          Expanded(
            child: _loading && _payments.isEmpty
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có QR thanh toán nào',
                              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadData(refresh: true),
                        color: _primaryColor,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _payments.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _payments.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: _primaryColor),
                                ),
                              );
                            }
                            return _buildPaymentCard(_payments[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox.shrink();
    
    final total = _stats!['total'] as int? ?? 0;
    final success = _stats!['success'] as int? ?? 0;
    final pending = _stats!['pending'] as int? ?? 0;
    final successRate = _stats!['successRate'] as double? ?? 0.0;
    final totalAmount = (_stats!['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Thống kê',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Tổng số', total.toString(), Colors.white),
                ),
                Expanded(
                  child: _buildStatItem('Đã TT', success.toString(), Colors.white),
                ),
                 Expanded(
                  child: _buildStatItem('Chờ TT', pending.toString(), Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
             Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tỷ lệ',
                    '${successRate.toStringAsFixed(1)}%',
                    Colors.white,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildStatItem(
                    'Tổng tiền',
                    _currencyFormatter.format(totalAmount),
                    Colors.white,
                    isLarge: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: color.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: isLarge ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
             setState(() => _statusFilter = value);
             _applyFilter();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade300),
            boxShadow: isSelected ? [
               BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
            ] : null,
          ),
          child: Text(
            label, 
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            )
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString() ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final invoiceInfo = payment['invoiceInfo'] as Map<String, dynamic>?;
    final createdAt = payment['createdAt'] != null
        ? DateTime.parse(payment['createdAt'])
        : null;
    final paidAt = payment['paidAt'] != null
        ? DateTime.parse(payment['paidAt'])
        : null;
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

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
          onTap: () => _showQRCode(payment),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (invoiceInfo != null) ...[
                            Text(
                              'Căn hộ: ${invoiceInfo['apartmentCode'] ?? 'N/A'}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hóa đơn ${invoiceInfo['month']}/${invoiceInfo['year']} - ${invoiceInfo['type']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else
                            Text(
                              'Payment #${payment['paymentId']?.toString().substring(0, 8)}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _currencyFormatter.format(amount),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.qr_code_2, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${payment['transactionCode']?.toString().substring(0, 8).toUpperCase() ?? 'N/A'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const Spacer(),
                    if (paidAt != null) ...[
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          _dateFormatter.format(paidAt.toLocal()),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                    ] else if (createdAt != null)
                      Text(
                        'Tạo: ${_dateFormatter.format(createdAt.toLocal())}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[500],
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

class _QRCodeDialog extends StatelessWidget {
  final String qrData;
  final Map<String, dynamic> payment;
  final double amount;
  final Map<String, dynamic>? invoiceInfo;

  const _QRCodeDialog({
    required this.qrData,
    required this.payment,
    required this.amount,
    this.invoiceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QR Code PayOS',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (invoiceInfo != null) ...[
                Text(
                  'Hóa đơn ${invoiceInfo!['month']}/${invoiceInfo!['year']}',
                  style: GoogleFonts.inter(color: Colors.grey.shade600),
                ),
                if (invoiceInfo!['apartmentCode'] != null)
                  Text(
                    'Căn hộ: ${invoiceInfo!['apartmentCode']}',
                    style: GoogleFonts.inter(color: Colors.grey.shade600),
                  ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 250,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số tiền:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(amount),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF009688),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã thanh toán:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          payment['transactionCode']?.toString().substring(0, 8).toUpperCase() ?? 'N/A',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                          ).copyWith(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14)
                  ),
                  child: Text('Đóng', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
