import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/config_url.dart';
import '../../core/services/payment_service.dart';
import 'invoice_detail_page.dart';

class VnPayPaymentPage extends StatefulWidget {
  final String invoiceId;

  const VnPayPaymentPage({super.key, required this.invoiceId});

  @override
  State<VnPayPaymentPage> createState() => _VnPayPaymentPageState();
}

class _VnPayPaymentPageState extends State<VnPayPaymentPage> {
  late final PaymentService _paymentService;
  String? _paymentUrl;
  String? _paymentId;
  bool _loading = true;
  bool _completed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    _paymentService = PaymentService(dio);
    _initPayment();
  }

  Future<void> _initPayment() async {
    try {
      final data = await _paymentService.createPayOsLinkForInvoice(widget.invoiceId);
      setState(() {
        _paymentUrl = (data['checkoutUrl'] ?? data['qrData'] ?? data['paymentUrl']) as String?;
        _paymentId = data['paymentId']?.toString();
        _loading = false;
      });

      if (_paymentId != null) {
        _startPolling();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể khởi tạo thanh toán: $e')),
      );
      Navigator.of(context).pop(false);
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_completed || _paymentId == null) return;

      try {
        final status = await _paymentService.getPaymentStatus(_paymentId!);
        final s = status['status']?.toString();
        if (s == 'Success') {
          _completed = true;
          timer.cancel();
          if (!mounted) return;
          // Chuyển về trang chi tiết hóa đơn sau khi thanh toán thành công
          Navigator.of(context).pop(); // Đóng payment page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => InvoiceDetailPage(invoiceId: widget.invoiceId),
            ),
          );
        } else if (s == 'Failed') {
          _completed = true;
          timer.cancel();
          if (!mounted) return;
          final code = status['errorCode']?.toString();
          final message = status['errorMessage']?.toString();
          final friendly = _mapPayOsError(code, message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thanh toán thất bại: $friendly')),
          );
          Navigator.of(context).pop(false);
        }
      } catch (_) {
        // bỏ qua lỗi poll
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _mapPayOsError(String? code, String? backendMessage) {
    if (backendMessage != null && backendMessage.isNotEmpty) return backendMessage;
    switch (code) {
      case '07':
        return 'Giao dịch bị nghi ngờ gian lận.';
      case '09':
        return 'Thẻ/Tài khoản chưa đăng ký Internet Banking.';
      case '10':
        return 'Sai thông tin thẻ/tài khoản quá số lần cho phép.';
      case '11':
        return 'Hết thời gian chờ thanh toán.';
      case '12':
        return 'Thẻ/Tài khoản bị khóa.';
      case '13':
        return 'Sai mật khẩu/OTP.';
      case '24':
        return 'Bạn đã hủy giao dịch.';
      case '51':
        return 'Không đủ số dư.';
      case '65':
        return 'Vượt hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng thanh toán đang bảo trì.';
      case '79':
        return 'Sai mật khẩu thanh toán quá số lần quy định.';
      case '97':
        return 'Chữ ký không hợp lệ.';
      case '99':
        return 'Lỗi không xác định từ PayOS.';
      default:
        return 'Vui lòng thử lại hoặc liên hệ ngân hàng.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán PayOS')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_paymentUrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán PayOS')),
        body: const Center(child: Text('Không có URL thanh toán')),
      );
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_paymentUrl!));

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán PayOS')),
      body: WebViewWidget(controller: controller),
    );
  }
}

/// Mở trực tiếp một URL VNPay (dùng khi đã có sẵn qrData/paymentUrl từ backend).
/// Có thể truyền kèm paymentId để trang tự poll trạng thái thanh toán.
class VnPayPaymentUrlPage extends StatefulWidget {
  final String paymentUrl;
  final String? paymentId;
  final String? invoiceId; // Invoice ID để chuyển về trang chi tiết sau khi thanh toán
  final String title;

  const VnPayPaymentUrlPage({
    super.key,
    required this.paymentUrl,
    this.paymentId,
    this.invoiceId,
    this.title = 'Thanh toán PayOS',
  });

  @override
  State<VnPayPaymentUrlPage> createState() => _VnPayPaymentUrlPageState();
}

class _VnPayPaymentUrlPageState extends State<VnPayPaymentUrlPage> {
  late final PaymentService _paymentService;
  bool _completed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    _paymentService = PaymentService(dio);
    if (widget.paymentId != null && widget.paymentId!.isNotEmpty) {
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_completed || widget.paymentId == null || widget.paymentId!.isEmpty) return;

      try {
        final status = await _paymentService.getPaymentStatus(widget.paymentId!);
        final s = status['status']?.toString();
        if (s == 'Success') {
          _completed = true;
          timer.cancel();
          if (!mounted) return;
          
          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanh toán thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Đợi một chút để user thấy thông báo
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!mounted) return;
          
          // Pop trang payment và return true để trigger refresh invoices list
          // Điều này sẽ đóng cả payment page và amenity booking page (nếu có)
          Navigator.of(context).pop(true);
          
        } else if (s == 'Failed') {
          _completed = true;
          timer.cancel();
          if (!mounted) return;
          final code = status['errorCode']?.toString();
          final message = status['errorMessage']?.toString();
          final friendly = _mapPayOsError(code, message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thanh toán thất bại: $friendly')),
          );
          Navigator.of(context).pop(false);
        }
      } catch (_) {
        // bỏ qua lỗi poll
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _mapPayOsError(String? code, String? backendMessage) {
    if (backendMessage != null && backendMessage.isNotEmpty) return backendMessage;
    switch (code) {
      case '07':
        return 'Giao dịch bị nghi ngờ gian lận.';
      case '09':
        return 'Thẻ/Tài khoản chưa đăng ký Internet Banking.';
      case '10':
        return 'Sai thông tin thẻ/tài khoản quá số lần cho phép.';
      case '11':
        return 'Hết thời gian chờ thanh toán.';
      case '12':
        return 'Thẻ/Tài khoản bị khóa.';
      case '13':
        return 'Sai mật khẩu/OTP.';
      case '24':
        return 'Bạn đã hủy giao dịch.';
      case '51':
        return 'Không đủ số dư.';
      case '65':
        return 'Vượt hạn mức giao dịch trong ngày.';
      case '75':
        return 'Ngân hàng thanh toán đang bảo trì.';
      case '79':
        return 'Sai mật khẩu thanh toán quá số lần quy định.';
      case '97':
        return 'Chữ ký không hợp lệ.';
      case '99':
        return 'Lỗi không xác định từ PayOS.';
      default:
        return 'Vui lòng thử lại hoặc liên hệ ngân hàng.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    
    // Set navigation delegate sau khi controller đã được tạo
    controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          // Cho phép tất cả các navigation
          return NavigationDecision.navigate;
        },
        onPageFinished: (String url) {
          // Nếu đang ở trang warning ngrok, tự động click nút "Visit Site" để bỏ qua
          if (url.contains('ngrok-free.dev') || url.contains('ngrok.io') || url.contains('ngrok')) {
            // Đợi một chút để trang load xong rồi mới click
            Future.delayed(const Duration(milliseconds: 500), () {
              controller.runJavaScript('''
                (function() {
                  // Tìm nút "Visit Site" - thử nhiều cách
                  var visitButton = null;
                  
                  // Cách 1: Tìm button có text "Visit Site" hoặc "Visit"
                  var buttons = document.querySelectorAll('button, a');
                  for (var i = 0; i < buttons.length; i++) {
                    var text = (buttons[i].textContent || buttons[i].innerText || '').trim();
                    if (text.includes('Visit Site') || text.includes('Visit') || 
                        text.includes('Tiếp tục') || text.includes('Continue')) {
                      visitButton = buttons[i];
                      break;
                    }
                  }
                  
                  // Cách 2: Tìm button có class chứa "visit" hoặc "continue"
                  if (!visitButton) {
                    visitButton = document.querySelector('button[class*="visit"], button[class*="continue"], a[class*="visit"], a[class*="continue"]');
                  }
                  
                  // Cách 3: Tìm button đầu tiên có href hoặc onclick
                  if (!visitButton) {
                    visitButton = document.querySelector('a[href], button[onclick]');
                  }
                  
                  // Cách 4: Tìm button đầu tiên
                  if (!visitButton) {
                    visitButton = document.querySelector('button, a');
                  }
                  
                  if (visitButton) {
                    visitButton.click();
                  } else {
                    // Nếu không tìm thấy, thử tìm form submit hoặc redirect
                    var forms = document.querySelectorAll('form');
                    if (forms.length > 0) {
                      forms[0].submit();
                    }
                  }
                })();
              ''');
            });
          }
        },
      ),
    );
    
    controller.loadRequest(Uri.parse(widget.paymentUrl));

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: controller),
    );
  }
}

