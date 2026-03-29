import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../amenities/amenities_service.dart';
import '../amenities/amenity_booking_model.dart';
import '../../core/ui/snackbar.dart';
import '../../core/api_client.dart';
import 'manager_shell.dart';

class AmenityBookingsAdminPage extends StatefulWidget {
  const AmenityBookingsAdminPage({super.key});

  @override
  State<AmenityBookingsAdminPage> createState() => _AmenityBookingsAdminPageState();
}

class _AmenityBookingsAdminPageState extends State<AmenityBookingsAdminPage> {
  final _svc = AmenitiesService();
  final _searchController = TextEditingController();
  
  List<AmenityBookingModel> _items = [];
  bool _loading = true;
  String? _filterStatus = 'Pending'; 

  // Modern Colors
  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final search = _searchController.text.trim();
      _items = await _svc.listBookings(
        status: _filterStatus == 'All' ? null : _filterStatus,
        search: search.isEmpty ? null : search,
      );
    } catch (e) {
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(AmenityBookingModel b) async {
    try {
      await _svc.approve(b.id);
      showSnack(context, 'Đã duyệt thành công', error: false);
      await _loadData();
    } on DioException catch (e) {
       String message = 'Không duyệt được lịch đặt';
       final data = e.response?.data;
       if (data is Map<String, dynamic> && data['error'] is String) {
         message = data['error'] as String;
       }
       showSnack(context, message, error: true);
    } catch (_) {
      showSnack(context, 'Lỗi hệ thống khi duyệt', error: true);
    }
  }

  Future<void> _reject(AmenityBookingModel b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Từ chối đặt lịch?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn từ chối yêu cầu của ${b.userName}?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Từ chối', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _svc.reject(b.id);
        if(!mounted) return;
        showSnack(context, 'Đã từ chối yêu cầu', error: false);
        await _loadData();
      } catch (e) {
        if(!mounted) return;
        showSnack(context, 'Lỗi: $e', error: true);
      }
    }
  }

  Future<void> _generatePaymentQR(AmenityBookingModel booking) async {
    if (booking.invoiceId == null || booking.invoiceId!.isEmpty) {
      showSnack(context, 'Không tìm thấy hóa đơn', error: true);
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      final response = await api.dio.post('/api/Payments/${booking.invoiceId}/generate-payos-qr');

      if (!mounted) return;
      Navigator.pop(context); 

      final qrData = response.data['qrData'] as String;
      final paymentId = response.data['paymentId'] as String;
      final amount = (response.data['amount'] as num).toDouble();

      showDialog(
        context: context,
        builder: (context) => _QRCodeDialog(
          qrData: qrData,
          booking: booking,
          amount: amount,
          paymentId: paymentId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Lỗi tạo QR: $e', error: true);
    }
  }

  // --- UI Components ---
  
  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 52), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Quản lý dịch vụ → Đặt lịch', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('Quản lý yêu cầu sử dụng tiện ích', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -28,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên cư dân hoặc tiện ích...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterStatus == key;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          setState(() => _filterStatus = key);
          _loadData();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade300,
            ),
            boxShadow: isSelected 
                ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(AmenityBookingModel b) {
    final fmtDate = DateFormat('dd/MM/yyyy');
    final fmtTime = DateFormat('HH:mm');
    final isPending = b.status == 'Pending';
    final isApproved = b.status == 'Approved';
    final isRejected = b.status == 'Rejected';
    
    Color statusColor = Colors.grey;
    String statusText = b.status;
    IconData statusIcon = Icons.help_outline;

    if (isPending) {
       statusColor = Colors.orange;
       statusText = 'Chờ duyệt';
       statusIcon = Icons.access_time_filled;
    } else if (isApproved) {
       statusColor = Colors.green;
       statusText = 'Đã duyệt';
       statusIcon = Icons.check_circle;
    } else if (isRejected) {
       statusColor = Colors.red;
       statusText = 'Đã từ chối';
       statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.spa_rounded, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.amenityName,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                       Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusText, style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildInfoLabel(Icons.person_outline, 'Người đặt'),
                       Text(b.userName, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15)),
                       const SizedBox(height: 12),
                       _buildInfoLabel(Icons.attach_money, 'Giá thanh toán'),
                       Text(b.price != null ? '${NumberFormat("#,###").format(b.price)} đ' : 'Miễn phí', 
                         style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _primaryColor, fontSize: 15)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildInfoLabel(Icons.calendar_today_outlined, 'Thời gian'),
                       Text(fmtDate.format(b.startTimeUtc.toLocal()), style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15)),
                       const SizedBox(height: 12),
                       _buildInfoLabel(Icons.schedule, 'Khung giờ'),
                       Text('${fmtTime.format(b.startTimeUtc.toLocal())} - ${fmtTime.format(b.endTimeUtc.toLocal())}', 
                         style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),

            if (isPending || (b.price != null && b.price! > 0 && b.invoiceId != null)) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (isPending) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(b),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Từ chối', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _approve(b),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text('Duyệt ngay', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  if (!isPending && b.price != null && b.price! > 0 && b.invoiceId != null) 
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generatePaymentQR(b),
                        icon: const Icon(Icons.qr_code),
                        label: Text('QR Thanh toán', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                         style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Không có lịch đặt nào',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            'Danh sách đang trống',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Duyệt đặt lịch', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => managerShellKey.currentState?.navigateToPage(0),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Container(
            height: 64, // Increased from 60 to prevent overflow
            margin: const EdgeInsets.only(top: 36, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildFilterChip('Pending', '⏳ Chờ duyệt'),
                _buildFilterChip('Approved', '✅ Đã duyệt'),
                _buildFilterChip('Rejected', '❌ Từ chối'),
                _buildFilterChip('All', 'Tất cả'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: _primaryColor,
                    child: _items.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _buildBookingCard(_items[i]),
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String qrData;
  final AmenityBookingModel booking;
  final double amount;
  final String paymentId;

  const _QRCodeDialog({
    required this.qrData,
    required this.booking,
    required this.amount,
    required this.paymentId,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final fmtDate = DateFormat('dd/MM/yyyy');
    final fmtTime = DateFormat('HH:mm');
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
          ]
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('QR Code PayOS', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(booking.amenityName, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                '${fmtDate.format(booking.startTimeUtc.toLocal())} ${fmtTime.format(booking.startTimeUtc.toLocal())} - ${fmtTime.format(booking.endTimeUtc.toLocal())}',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ]
                ),
                child: QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Số tiền:', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                        Text(currencyFormatter.format(amount), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mã thanh toán:', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                        Text(paymentId.substring(0, 8).toUpperCase(), style: GoogleFonts.robotoMono(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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