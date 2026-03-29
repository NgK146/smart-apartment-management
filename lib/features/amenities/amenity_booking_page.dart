import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/ui/snackbar.dart';
import '../../core/api_client.dart';
import '../../config/config_url.dart';
import 'amenities_service.dart';
import 'amenity_model.dart';
import '../resident/resident_service.dart';
import '../resident/link_apartment_page.dart';
import '../auth/auth_provider.dart';
import '../billing/vn_pay_payment_page.dart';
import '../billing/invoice_detail_page.dart';
import '../../core/services/payment_service.dart';

const Duration _vietnamTimeOffset = Duration(hours: 7);

DateTime _toVietnamDisplay(DateTime date) {
  final normalizedUtc = date.toUtc();
  final shifted = normalizedUtc.add(_vietnamTimeOffset);
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

DateTime _fromVietnamDisplay(DateTime vietnamTime) {
  final asUtc = DateTime.utc(
    vietnamTime.year,
    vietnamTime.month,
    vietnamTime.day,
    vietnamTime.hour,
    vietnamTime.minute,
    vietnamTime.second,
    vietnamTime.millisecond,
    vietnamTime.microsecond,
  );
  return asUtc.subtract(_vietnamTimeOffset);
}

String _formatVietnamDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatVietnamTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class AmenityBookingPage extends StatefulWidget {
  final Amenity amenity;
  const AmenityBookingPage({super.key, required this.amenity});
  @override State<AmenityBookingPage> createState()=>_AmenityBookingPageState();
}

class _AmenityBookingPageState extends State<AmenityBookingPage> {
  final _svc = AmenitiesService();
  final _residentSvc = ResidentService();
  final _paymentService = PaymentService(api.dio);
  late DateTime _startUtc;
  late DateTime _endUtc;
  bool _loading=false;
  DateTime _week = DateTime.now().toUtc();
  List<Map<String,dynamic>> _slots = [];
  double? _pricePerSlot;
  final _purpose = TextEditingController();
  final _participants = TextEditingController();
  final _phone = TextEditingController();
  int _reminderMinutes = 60;
  ResidentProfileVm? _profile;
  bool _loadingProfile = true;

  DateTime get _startDisplay => _toVietnamDisplay(_startUtc);
  DateTime get _endDisplay => _toVietnamDisplay(_endUtc);

  DateTime get _nowUtc => DateTime.now().toUtc();

  bool _isPastUtc(DateTime valueUtc) => !valueUtc.isAfter(_nowUtc);

  bool _isBeyondFutureLimit(DateTime valueUtc) {
    final futureLimitUtc = _nowUtc.add(const Duration(days: 90));
    return valueUtc.isAfter(futureLimitUtc);
  }

  @override void initState(){ 
    super.initState(); 
    final nowUtc = _nowUtc;
    _startUtc = nowUtc.add(const Duration(hours: 1));
    _endUtc = nowUtc.add(const Duration(hours: 2));
    _week = nowUtc;
    _loadProfile();
    _loadSlots(); 
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      _profile = await _residentSvc.myProfile();
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadSlots() async {
    setState(()=>_loading=true);
    try {
      final monday = _week.subtract(Duration(days: (_week.weekday+6)%7)).toUtc();
      final res = await api.dio.get('/api/AmenityBookings/availability', queryParameters: {
        'amenityId': widget.amenity.id,
        'weekStartUtc': monday.toIso8601String(),
      });
      final data = Map<String,dynamic>.from(res.data);
      _pricePerSlot = (data['pricePerSlot'] as num?)?.toDouble();
      _slots = (data['items'] as List).map((e)=> Map<String,dynamic>.from(e)).toList();
    } catch (_) {}
    finally { if(mounted) setState(()=>_loading=false); }
  }

  Future<void> _pickStart() async {
    final nowVietnam = _toVietnamDisplay(_nowUtc);
    final maxDate = nowVietnam.add(const Duration(days: 90));
    final currentStart = _startDisplay;
    final initialDate = currentStart.isBefore(nowVietnam) ? nowVietnam : currentStart;
    final d = await showDatePicker(
      context: context, 
      firstDate: nowVietnam, 
      lastDate: maxDate, 
      initialDate: initialDate,
      helpText: 'Chọn ngày bắt đầu',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d==null) return;
    final t = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay(hour: currentStart.hour, minute: currentStart.minute),
      helpText: 'Chọn giờ bắt đầu',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (t==null) return;
    final selectedVietnam = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final selectedUtc = _fromVietnamDisplay(selectedVietnam);
    
    // Validate: Không được chọn thời gian trong quá khứ
    if (_isPastUtc(selectedUtc)) {
      if (mounted) {
        _showValidationError(
          icon: Icons.access_time_rounded,
          title: 'Thời gian không hợp lệ',
          message: 'Bạn không thể đặt lịch trong quá khứ.\nVui lòng chọn thời gian từ bây giờ trở đi.',
          actionText: 'Đã hiểu',
        );
      }
      return;
    }
    
    // Validate: Không được đặt quá xa trong tương lai (90 ngày)
    if (_isBeyondFutureLimit(selectedUtc)) {
      if (mounted) {
        _showValidationError(
          icon: Icons.calendar_today_rounded,
          title: 'Thời gian quá xa',
          message: 'Bạn chỉ có thể đặt lịch trong vòng 90 ngày tới.\nVui lòng chọn thời gian gần hơn.',
          actionText: 'Đã hiểu',
        );
      }
      return;
    }
    
    setState(()=> _startUtc = selectedUtc);
    if (_endUtc.isBefore(_startUtc.add(const Duration(hours: 1)))) {
      setState(()=> _endUtc = _startUtc.add(const Duration(hours: 1)));
    }
  }

  Future<void> _pickEnd() async {
    final startVietnam = _startDisplay;
    final currentEnd = _endDisplay;
    final maxDate = startVietnam.add(const Duration(days: 1));
    final initialEnd = currentEnd.isBefore(startVietnam) ? startVietnam.add(const Duration(hours: 1)) : currentEnd;
    final d = await showDatePicker(
      context: context, 
      firstDate: startVietnam, 
      lastDate: maxDate, 
      initialDate: initialEnd,
      helpText: 'Chọn ngày kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d==null) return;
    final t = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay(hour: currentEnd.hour, minute: currentEnd.minute),
      helpText: 'Chọn giờ kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (t==null) return;
    final selectedVietnam = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    final selectedUtc = _fromVietnamDisplay(selectedVietnam);
    
    // Validate: Thời gian kết thúc phải sau thời gian bắt đầu
    if (selectedUtc.isBefore(_startUtc) || selectedUtc.isAtSameMomentAs(_startUtc)) {
      if (mounted) {
        _showValidationError(
          icon: Icons.schedule_rounded,
          title: 'Thời gian không hợp lệ',
          message: 'Thời gian kết thúc phải sau thời gian bắt đầu.\nVui lòng chọn lại.',
          actionText: 'Đã hiểu',
        );
      }
      return;
    }
    
    // Validate: Thời gian kết thúc không được trong quá khứ
    if (_isPastUtc(selectedUtc)) {
      if (mounted) {
        _showValidationError(
          icon: Icons.access_time_rounded,
          title: 'Thời gian không hợp lệ',
          message: 'Thời gian kết thúc không thể trong quá khứ.\nVui lòng chọn thời gian từ bây giờ trở đi.',
          actionText: 'Đã hiểu',
        );
      }
      return;
    }
    
    setState(()=> _endUtc = selectedUtc);
  }
  
  void _showValidationError({
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon với animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final nowUtc = _nowUtc;
    
    // Validate: Không được đặt lịch trong quá khứ
    if (_isPastUtc(_startUtc)) {
      _showValidationError(
        icon: Icons.access_time_rounded,
        title: 'Thời gian không hợp lệ',
        message: 'Bạn không thể đặt lịch trong quá khứ.\nVui lòng chọn thời gian từ bây giờ trở đi.',
        actionText: 'Đã hiểu',
      );
      return;
    }
    
    // Validate: Không được đặt quá xa trong tương lai
    if (_isBeyondFutureLimit(_startUtc)) {
      _showValidationError(
        icon: Icons.calendar_today_rounded,
        title: 'Thời gian quá xa',
        message: 'Bạn chỉ có thể đặt lịch trong vòng 90 ngày tới.\nVui lòng chọn thời gian gần hơn.',
        actionText: 'Đã hiểu',
      );
      return;
    }
    
    // Validate: Thời gian kết thúc phải sau thời gian bắt đầu
    if (_endUtc.isBefore(_startUtc) || _endUtc.isAtSameMomentAs(_startUtc)) {
      _showValidationError(
        icon: Icons.schedule_rounded,
        title: 'Thời gian không hợp lệ',
        message: 'Thời gian kết thúc phải sau thời gian bắt đầu.\nVui lòng chọn lại.',
        actionText: 'Đã hiểu',
      );
      return;
    }
    
    // Validate: Thời gian kết thúc không được trong quá khứ
    if (_endUtc.isBefore(nowUtc)) {
      _showValidationError(
        icon: Icons.access_time_rounded,
        title: 'Thời gian không hợp lệ',
        message: 'Thời gian kết thúc không thể trong quá khứ.\nVui lòng chọn thời gian từ bây giờ trở đi.',
        actionText: 'Đã hiểu',
      );
      return;
    }
    
    setState(()=>_loading=true);
    try {
      final participantCount = int.tryParse(_participants.text.trim());
      final result = await _svc.book(
        amenityId: widget.amenity.id, 
        start: _startUtc, 
        end: _endUtc,
        purpose: _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
        participantCount: participantCount,
        contactPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        reminderOffsetMinutes: _reminderMinutes,
      );
      if (!mounted) return;

      final invoiceId = result['invoiceId']?.toString();
      final amount = (result['amount'] as num?)?.toDouble() ?? 0;
      final qrDataRaw = result['qrData']?.toString();
      String? qrData = qrDataRaw?.trim(); // Trim để loại bỏ whitespace
      String? paymentId = result['paymentId']?.toString();

      // Debug: Log response để kiểm tra
      print('🔍 Booking response: invoiceId=$invoiceId, amount=$amount, qrData=${qrData != null ? (qrData.isEmpty ? "EMPTY" : "HAS_DATA (${qrData.length} chars)") : "NULL"}, paymentId=$paymentId');
      if (qrData != null && qrData.isNotEmpty) {
        print('🔍 QR Data preview: ${qrData.substring(0, qrData.length > 50 ? 50 : qrData.length)}...');
        // Đảm bảo QR data là URL PayOS hợp lệ
        if (!qrData.startsWith('http')) {
          print('⚠️ WARNING: QR data không phải là URL hợp lệ, có thể là QR code cũ. Sẽ tạo lại QR PayOS mới.');
          qrData = null; // Reset để tạo lại QR PayOS mới
        }
      } else if (amount > 0 && qrData == null) {
        print('⚠️ WARNING: Có phí ($amount) nhưng không có QR code. Có thể PayOS chưa được cấu hình hoặc có lỗi khi tạo payment URL.');
      } else if (amount == 0) {
        print('ℹ️ INFO: Tiện ích này miễn phí (amount=0) nên không cần QR code thanh toán.');
      }

      // Nếu có invoice nhưng chưa có QR PayOS, tạo QR PayOS mới ngay lập tức
      if ((qrData == null || qrData.isEmpty) && invoiceId != null && amount > 0) {
        final regenerated = await _regenerateQrForInvoice(invoiceId);
        if (regenerated != null) {
          qrData = regenerated.qrData;
          paymentId = regenerated.paymentId ?? paymentId;
        }
      }

      // Nếu có QR code PayOS hợp lệ, vào thẳng trang PayOS để thanh toán
      if (qrData != null && qrData.isNotEmpty && amount > 0) {
        if (!mounted) return;
        showSnack(context, 'Đặt lịch thành công! Đang chuyển đến trang thanh toán...');
        // Vào thẳng trang PayOS để thanh toán, không hiển thị QR dialog
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VnPayPaymentUrlPage(
              paymentUrl: qrData!,
              paymentId: paymentId,
              invoiceId: invoiceId,
              title: 'Thanh toán PayOS',
            ),
          ),
        );
        
        // Nếu thanh toán thành công, navigate đến trang invoice detail
        if (mounted) {
          if (paymentResult == true && invoiceId != null) {
            // Pop booking page trước
            Navigator.pop(context, true);
            // Navigate đến invoice detail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: invoiceId),
              ),
            );
          } else {
            Navigator.pop(context, paymentResult == true);
          }
        }
        return;
      }

      // Nếu có invoice nhưng chưa có QR (lỗi tạo QR hoặc admin chưa cấu hình)
      if (invoiceId != null && amount > 0) {
        final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
        
        // Hiển thị dialog thông báo rõ ràng hơn về việc không có QR code
        final goPay = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.payment, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Thanh toán tiện ích')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiện ích này có phí ${formatter.format(amount)}.',
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                // Hiển thị cảnh báo vì QR code chưa được tạo (admin chưa cấu hình PayOS hoặc có lỗi)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QR code thanh toán chưa được cấu hình. Vui lòng thanh toán qua PayOS hoặc liên hệ Ban quản lý.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Bạn muốn thanh toán qua PayOS ngay bây giờ?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Thanh toán PayOS'),
              ),
            ],
          ),
        );

        if (goPay == true) {
          final payResult = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => VnPayPaymentPage(invoiceId: invoiceId)),
          );
          if (payResult == true && mounted) {
            showSnack(context, 'Đặt lịch và thanh toán thành công');
            Navigator.pop(context, true);
            return;
          }
        }

        showSnack(context, 'Đặt lịch thành công. Bạn có thể thanh toán sau trong mục Hóa đơn.');
        Navigator.pop(context, true);
      } else {
        final auto = (widget.amenity.allowBooking == true) && (widget.amenity.pricePerHour == null || widget.amenity.pricePerHour == 0) && !(widget.amenity.requireManualApproval ?? false);
        showSnack(context, auto ? 'Đặt lịch thành công (tự động duyệt).' : 'Đã gửi yêu cầu đặt lịch. Vui lòng chờ duyệt.');
        Navigator.pop(context, true);
      }
    } catch(e){ 
      var message = 'Đặt lịch lỗi: $e';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }
      }
      showSnack(context, message, error: true); 
    } finally { 
      if(mounted) setState(()=>_loading=false); 
    }
  }

  Future<_PaymentQrResult?> _regenerateQrForInvoice(String invoiceId) async {
    try {
      final data = await _paymentService.createPayOsLinkForInvoice(invoiceId);
      final qrData = (data['qrData'] ?? data['paymentUrl'])?.toString().trim();
      if (qrData == null || qrData.isEmpty) return null;
      final newPaymentId = data['paymentId']?.toString();
      print('ℹ️ Regenerated QR for invoice $invoiceId, paymentId=$newPaymentId');
      return _PaymentQrResult(qrData: qrData, paymentId: newPaymentId);
    } catch (e) {
      print('⚠️ Không thể tạo lại QR cho invoice $invoiceId: $e');
      return null;
    }
  }

  @override Widget build(BuildContext context) {
    final a = widget.amenity;
    final theme = Theme.of(context);
    final authState = context.watch<AuthState>();
    final startDisplay = _startDisplay;
    final endDisplay = _endDisplay;
    
    // Kiểm tra căn hộ từ cả ResidentProfile và AuthState
    final apartmentFromProfile = _profile?.apartmentCode ?? '';
    final apartmentFromAuth = authState.apartmentCode ?? '';
    final apartmentCode = apartmentFromProfile.isNotEmpty && apartmentFromProfile != '0' 
        ? apartmentFromProfile 
        : (apartmentFromAuth.isNotEmpty && apartmentFromAuth != '0' ? apartmentFromAuth : '');
    
    final hasApartment = apartmentCode.isNotEmpty && apartmentCode != '0';
    final isVerified = _profile?.isVerifiedByBQL ?? authState.isResidentVerified;
    
    final gridHeight = (MediaQuery.of(context).size.height * 0.45).clamp(280.0, 520.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt: ${a.name}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          )),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
        Expanded(
          child: ListView(
            children: [
          // Hiển thị hình ảnh tiện ích (nếu có)
          if (a.imageUrl != null && a.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  AppConfig.resolve(a.imageUrl!),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            'Không hiển thị được ảnh',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Hiển thị thông tin căn hộ hoặc nút liên kết
          if (_loadingProfile)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Đang tải thông tin...', style: theme.textTheme.bodyMedium),
                ]),
              ),
            )
          else if (!hasApartment)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade50, Colors.orange.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chưa liên kết căn hộ', 
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold, 
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Vui lòng liên kết căn hộ để đặt tiện ích.', 
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const LinkApartmentPage()),
                        );
                        if (result == true) {
                          await _loadProfile();
                          await authState.loadProfile(); // Cập nhật AuthState
                        }
                      },
                      icon: const Icon(Icons.link, size: 20),
                      label: const Text('Liên kết căn hộ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!isVerified)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.cyan.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Căn hộ: $apartmentCode', 
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, 
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.schedule, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text('Đang chờ Ban quản lý duyệt', 
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.blue.shade700),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.teal.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 1.5),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_rounded, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Căn hộ: $apartmentCode', 
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, 
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text('Đã được xác minh', 
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Thông tin tiện ích
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.description != null && a.description!.isNotEmpty) ...[
                  Text(a.description!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                ],
                if (a.pricePerHour != null) ...[
                  Row(children: [
                    Icon(Icons.attach_money, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Giá/giờ: ${a.pricePerHour!.toStringAsFixed(0)} đ', 
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Chọn thời gian
          Text('Thời gian sử dụng', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children:[
            Expanded(
              child: InkWell(
                onTap: _pickStart,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.schedule, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Bắt đầu', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _formatVietnamDate(startDisplay),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatVietnamTime(startDisplay),
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickEnd,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.event, size: 20, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Kết thúc', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _formatVietnamDate(endDisplay),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatVietnamTime(endDisplay),
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          // Thông tin bổ sung
          Text('Thông tin bổ sung', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _purpose, 
            decoration: InputDecoration(
              labelText: 'Mục đích sử dụng (tuỳ chọn)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children:[
            Expanded(
              child: TextField(
                controller: _participants, 
                decoration: InputDecoration(
                  labelText: 'Số người (tuỳ chọn)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phone, 
                decoration: InputDecoration(
                  labelText: 'SĐT liên hệ (tuỳ chọn)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _reminderMinutes,
            decoration: InputDecoration(
              labelText: 'Nhắc trước',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 phút')),
              DropdownMenuItem(value: 60, child: Text('60 phút')),
              DropdownMenuItem(value: 120, child: Text('120 phút')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _reminderMinutes = v);
            },
          ),
          const SizedBox(height: 20),
          Row(children:[
            Text('Lịch trống tuần này', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: _loading? null : (){ 
                setState(()=> _week = _week.subtract(const Duration(days:7))); 
                _loadSlots(); 
              }, 
              icon: Icon(Icons.chevron_left, color: theme.colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading? null : (){ 
                setState(()=> _week = _week.add(const Duration(days:7))); 
                _loadSlots(); 
              }, 
              icon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          SizedBox(
            height: gridHeight,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildGrid(),
          ),
          const SizedBox(height: 24),
        ],
          ),
        ),
        const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, 
            height: 56,
            child: FilledButton(
              onPressed: (_loading || !hasApartment) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: hasApartment ? theme.colorScheme.primary : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: hasApartment ? 2 : 0,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasApartment ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          hasApartment ? 'Xác nhận đặt lịch' : 'Vui lòng liên kết căn hộ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGrid(){
    if (_slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Không có dữ liệu lịch', 
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    // nhóm theo ngày
    final groups = <String, List<Map<String,dynamic>>>{};
    for (final slot in _slots){
      final startUtc = DateTime.parse(slot['startUtc'].toString()).toUtc();
      final endUtc = DateTime.parse(slot['endUtc'].toString()).toUtc();
      final startVietnam = _toVietnamDisplay(startUtc);
      final endVietnam = _toVietnamDisplay(endUtc);
      final key = '${startVietnam.year}-${startVietnam.month}-${startVietnam.day}';
      final enriched = Map<String, dynamic>.from(slot)
        ..['_startUtc'] = startUtc
        ..['_endUtc'] = endUtc
        ..['_startVietnam'] = startVietnam
        ..['_endVietnam'] = endVietnam;
      groups.putIfAbsent(key, ()=>[]).add(enriched);
    }
    final days = groups.keys.toList()..sort();
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (_, i){
        final key = days[i]; 
        final items = groups[key]!;
        final date = (items.first['_startVietnam'] as DateTime);
        final weekday = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][date.weekday % 7];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      '$weekday, ${date.day}/${date.month}/${date.year}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((slot) {
                  final startUtc = slot['_startUtc'] as DateTime;
                  final endUtc = slot['_endUtc'] as DateTime;
                  final startVietnam = slot['_startVietnam'] as DateTime;
                  final endVietnam = slot['_endVietnam'] as DateTime;
                  final ok = slot['available'] == true && !_isPastUtc(startUtc);
                  final sel = (_startUtc == startUtc && _endUtc == endUtc);
                  
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_formatVietnamTime(startVietnam)} - ${_formatVietnamTime(endVietnam)}'),
                        if (_pricePerSlot != null) ...[
                          const SizedBox(width: 4),
                          Text('• ${_pricePerSlot!.toStringAsFixed(0)} đ', 
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                    selected: sel,
                    onSelected: ok ? (v) {
                      if (v) {
                        if (_isPastUtc(startUtc)) {
                          _showValidationError(
                            icon: Icons.history_toggle_off_rounded,
                            title: 'Khung giờ đã trôi qua',
                            message: 'Khung giờ này đã không còn hiệu lực.\nVui lòng chọn một khung giờ khác ở tương lai.',
                            actionText: 'Chọn giờ khác',
                          );
                          return;
                        }
                        setState(() {
                          _startUtc = startUtc;
                          _endUtc = endUtc;
                        });
                      }
                    } : null,
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: sel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: sel ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
                      width: sel ? 2 : 1,
                    ),
                    disabledColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentQrResult {
  final String qrData;
  final String? paymentId;
  const _PaymentQrResult({required this.qrData, this.paymentId});
}


class _PaymentQRDialog extends StatefulWidget {
  final String qrData;
  final String amenityName;
  final double amount;
  final String paymentId;
  final String? invoiceId; // Invoice ID để chuyển về trang chi tiết sau khi thanh toán
  final DateTime startTime;
  final DateTime endTime;
  final VoidCallback onClose;
  final PaymentService paymentService;

  const _PaymentQRDialog({
    required this.qrData,
    required this.amenityName,
    required this.amount,
    required this.paymentId,
    this.invoiceId,
    required this.startTime,
    required this.endTime,
    required this.paymentService,
    required this.onClose,
  });

  @override
  State<_PaymentQRDialog> createState() => _PaymentQRDialogState();
}

class _PaymentQRDialogState extends State<_PaymentQRDialog> {
  Timer? _pollTimer;
  bool _checking = false;
  bool _paid = false;
  String? _currentQrData; // Lưu QR data hiện tại để tránh cache

  @override
  void initState() {
    super.initState();
    _currentQrData = widget.qrData; // Lưu QR data mới nhất
    _startPolling();
  }

  @override
  void didUpdateWidget(_PaymentQRDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu QR data thay đổi, cập nhật lại
    if (oldWidget.qrData != widget.qrData) {
      setState(() {
        _currentQrData = widget.qrData;
      });
    }
  }

  void _startPolling() {
    if (widget.paymentId.isEmpty) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_checking || _paid || widget.paymentId.isEmpty) return;
    setState(() => _checking = true);
    try {
      final status = await widget.paymentService.getPaymentStatus(widget.paymentId);
      final state = status['status']?.toString().toLowerCase();
      if (state == 'success') {
        setState(() => _paid = true);
        showSnack(context, 'Thanh toán thành công!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          // Nếu có invoiceId, chuyển về trang chi tiết hóa đơn
          if (widget.invoiceId != null && widget.invoiceId!.isNotEmpty) {
            Navigator.pop(context); // Đóng QR dialog
            Navigator.pop(context); // Đóng booking page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: widget.invoiceId!),
              ),
            );
          } else {
            widget.onClose();
          }
        }
      } else if (state == 'failed') {
        _pollTimer?.cancel();
        final code = status['errorCode']?.toString();
        final message = status['errorMessage']?.toString();
        final friendly = _mapPayOsError(code, message);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Thanh toán thất bại'),
            content: Text(friendly),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // ignore transient errors
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _mapPayOsError(String? code, String? backendMessage) {
    if (backendMessage != null && backendMessage.isNotEmpty) return backendMessage;
    switch (code) {
      case '07':
        return 'Giao dịch bị nghi ngờ gian lận. Vui lòng liên hệ ngân hàng hoặc PayOS.';
      case '09':
        return 'Thẻ/Tài khoản chưa đăng ký Internet Banking.';
      case '10':
        return 'Bạn đã nhập sai thông tin thẻ/tài khoản quá số lần cho phép.';
      case '11':
        return 'Giao dịch đã hết thời gian chờ thanh toán. Vui lòng thực hiện lại.';
      case '12':
        return 'Thẻ/Tài khoản của bạn đang bị khóa.';
      case '13':
        return 'Sai mật khẩu/OTP. Vui lòng thử lại.';
      case '24':
        return 'Bạn đã hủy giao dịch.';
      case '51':
        return 'Tài khoản không đủ số dư để thực hiện giao dịch.';
      case '65':
        return 'Bạn đã vượt quá hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng thanh toán đang bảo trì. Vui lòng thử lại sau.';
      case '79':
        return 'Sai mật khẩu thanh toán quá số lần quy định.';
      case '97':
        return 'Chữ ký không hợp lệ. Vui lòng thử lại.';
      case '99':
        return 'Lỗi không xác định từ PayOS.';
      default:
        return 'Thanh toán không thành công. Vui lòng thử lại hoặc dùng phương thức khác.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final startVietnam = _toVietnamDisplay(widget.startTime);
    final endVietnam = _toVietnamDisplay(widget.endTime);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QR Code Thanh toán',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.amenityName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatVietnamDate(startVietnam)} ${_formatVietnamTime(startVietnam)} - ${_formatVietnamTime(endVietnam)}',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
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
                  key: ValueKey(_currentQrData ?? widget.qrData), // Force rebuild khi QR data thay đổi
                  data: _currentQrData ?? widget.qrData,
                  size: 250,
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              // Nút mở PayOS trong app (WebView) – không cần dùng app ngân hàng
              if ((_currentQrData ?? widget.qrData).isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final qrDataToUse = _currentQrData ?? widget.qrData;
                      if (!qrDataToUse.startsWith('http')) {
                        showSnack(
                          context,
                          'Link thanh toán không hợp lệ. Vui lòng quét QR bằng app ngân hàng.',
                          error: true,
                        );
                        return;
                      }
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => VnPayPaymentUrlPage(
                            paymentUrl: qrDataToUse,
                            paymentId: widget.paymentId.isNotEmpty ? widget.paymentId : null,
                            title: 'Thanh toán PayOS',
                            invoiceId: widget.invoiceId,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        // Nếu thanh toán thành công trong WebView và có invoiceId, chuyển về invoice detail
                        if (widget.invoiceId != null && widget.invoiceId!.isNotEmpty) {
                          // Đóng QR dialog và booking page
                          Navigator.pop(context); // Đóng QR dialog
                          Navigator.pop(context); // Đóng booking page nếu có
                          // Chuyển đến trang chi tiết hóa đơn
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InvoiceDetailPage(invoiceId: widget.invoiceId!),
                            ),
                          );
                        } else {
                          widget.onClose();
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Thanh toán trong ứng dụng (PayOS)'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
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
                          currencyFormatter.format(widget.amount),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
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
                          widget.paymentId.isNotEmpty && widget.paymentId.length >= 8
                              ? widget.paymentId.substring(0, 8).toUpperCase()
                              : widget.paymentId.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                          ).copyWith(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 12),
              _buildStatusRow(theme),
              if (!_paid && widget.paymentId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _checking ? null : _checkStatus,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_checking ? 'Đang kiểm tra...' : 'Đã quét QR? Kiểm tra trạng thái'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quét QR code này bằng app ngân hàng để thanh toán',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        // Share QR code
                        try {
                          // Có thể dùng share_plus package hoặc copy to clipboard
                          // Tạm thời copy QR data vào clipboard
                          // await Clipboard.setData(ClipboardData(text: qrData));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép QR code')),
                            );
                          }
                        } catch (e) {
                          // Ignore
                        }
                        widget.onClose();
                      },
                      icon: Icon(_paid ? Icons.check_circle : Icons.share),
                      label: Text(_paid ? 'Đã thanh toán' : 'Chia sẻ'),
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

  Widget _buildStatusRow(ThemeData theme) {
    final color = _paid ? Colors.green : Colors.orange;
    final text = _paid ? 'Đã thanh toán' : 'Chờ thanh toán';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_paid ? Icons.check_circle : Icons.timelapse, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (widget.paymentId.isEmpty)
          Text(
            'Không có mã thanh toán',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}


