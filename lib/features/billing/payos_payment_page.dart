import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/config_url.dart';
import '../../core/api_client.dart';
import '../../core/services/payment_service.dart';
import '../../core/ui/snackbar.dart';
import 'invoice_model.dart';

/// PayOS 支付页面：嵌入 WebView + QR 码，支持轮询结果
class PayOsPaymentPage extends StatefulWidget {
  final InvoiceModel invoice;
  final String paymentId;
  final String checkoutUrl;
  final String? qrCode;
  final String? orderCode;

  const PayOsPaymentPage({
    super.key,
    required this.invoice,
    required this.paymentId,
    required this.checkoutUrl,
    this.qrCode,
    this.orderCode,
  });

  @override
  State<PayOsPaymentPage> createState() => _PayOsPaymentPageState();
}

class _PayOsPaymentPageState extends State<PayOsPaymentPage> {
  final _paymentService = PaymentService(api.dio);
  final _currencyStyle =
      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

  WebViewController? _webController;
  Uint8List? _qrBytes;
  bool _webFailed = false;
  bool _checking = false;
  bool _isPaid = false;
  String? _statusMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _prepareQrImage();
    _webController = _buildWebController(widget.checkoutUrl);
    _startAutoPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _webController = null; // Clear WebView controller to prevent memory leaks
    super.dispose();
  }

  void _prepareQrImage() {
    final raw = widget.qrCode;
    if (raw == null || raw.isEmpty) return;
    try {
      if (raw.startsWith('data:image')) {
        final base64Part = raw.split(',').last;
        _qrBytes = base64Decode(base64Part);
      } else if (!raw.startsWith('http')) {
        _qrBytes = base64Decode(raw);
      }
    } catch (_) {
      _qrBytes = null;
    }
  }

  WebViewController? _buildWebController(String url) {
    try {
      final uri = Uri.parse(url);
      return WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'DeepLinkChannel',
          onMessageReceived: (JavaScriptMessage message) {
            debugPrint('🔗 JavaScript message: ${message.message}');
            
            // Handle close message from payment success page button
            if (message.message == 'close') {
              debugPrint('📱 Closing payment page and refreshing invoices');
              if (mounted) {
                Navigator.of(context).pop(true); // Close PaymentPage
              }
              return;
            }
            
            // Handle deep link URLs (legacy, pode remover se não usar)
            final deepLinkUrl = message.message;
            if (deepLinkUrl.startsWith('icitizen://')) {
              final uri = Uri.tryParse(deepLinkUrl);
              if (uri != null && mounted) {
                launchUrl(uri, mode: LaunchMode.externalApplication).then((success) {
                  debugPrint('🚀 Deep link launch from JS: $success');
                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                }).catchError((e) {
                  debugPrint('❌ Deep link launch error: $e');
                });
              }
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              debugPrint(' Page loaded: $url');
            },
            onNavigationRequest: (navReq) {
              final target = navReq.url;
              debugPrint('🧭 Navigation request: $target');
              
              // Intercept deep link
              if (target.startsWith('icitizen://')) {
                debugPrint('🔗 Deep link in navigation: $target');
                final uri = Uri.tryParse(target);
                if (uri != null && mounted) {
                  launchUrl(uri, mode: LaunchMode.externalApplication).then((success) {
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  });
                }
                return NavigationDecision.prevent;
              }
              
              // Intercept API payment callbacks
              final base = AppConfig.apiBaseUrl;
              if (target.startsWith('$base/payment/')) {
                debugPrint('🔙 API redirect detected');
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
                return NavigationDecision.prevent;
              }
              
              return NavigationDecision.navigate;
            },
            onWebResourceError: (details) {
              final errorUrl = details.url ?? '';
              debugPrint('❌ WebView error: ${details.description}, URL: $errorUrl');
              // Ignore errors for deep links
              if (errorUrl.startsWith('icitizen://')) {
                debugPrint('🟢 Ignoring deep link error (handled by channel)');
                return;
              }
              setState(() => _webFailed = true);
            },
          ),
        )
        ..loadRequest(uri);
    } catch (_) {
      setState(() => _webFailed = true);
      return null;
    }
  }

  void _startAutoPolling() {
    _pollTimer =
        Timer.periodic(const Duration(seconds: 6), (_) => _checkStatus(silent: true));
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_checking || _isPaid) return;
    setState(() => _checking = true);
    try {
      final data = await _paymentService.getPaymentStatus(widget.paymentId);
      final status = (data['status'] ?? '').toString();
      if (status.toLowerCase() == 'success') {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isPaid = true;
          _statusMessage =
              'PayOS đã xác nhận. Bạn có thể quay lại danh sách hóa đơn.';
        });
        showSnack(context, 'Thanh toán PayOS thành công');
      } else {
        if (!mounted) return;
        setState(() => _statusMessage = 'Trạng thái hiện tại: $status');
        if (!silent) showSnack(context, 'Trạng thái: $status');
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        showSnack(context, 'Không kiểm tra được trạng thái: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.checkoutUrl);
    if (uri == null) {
      if (mounted) showSnack(context, 'Link không hợp lệ', error: true);
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showSnack(context, 'Không mở được PayOS', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Cleanup when page is popped
          debugPrint('🧹 Cleaning up PayOS payment page');
          _pollTimer?.cancel();
          _webController = null;
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          elevation: 0,
          title: const Text('Thanh toán PayOS'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Mở ngoài trình duyệt',
              icon: const Icon(Icons.open_in_browser),
              onPressed: _openExternal,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(theme),
                  const SizedBox(height: 16),
                  _buildWebSection(theme, constraints.maxHeight),
                  const SizedBox(height: 16),
                  _buildQrSection(theme),
                  const SizedBox(height: 16),
                  _buildStatusSection(theme),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : () => _checkStatus(),
                    icon: _checking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Tôi đã thanh toán – Kiểm tra trạng thái'),
                  ),
                ),
                if (_isPaid) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Quay lại hoá đơn'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hoá đơn ${widget.invoice.month}/${widget.invoice.year}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Căn hộ'),
                Text(widget.invoice.apartmentCode ?? 'N/A',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số tiền'),
                Text('${widget.invoice.totalAmount.toStringAsFixed(0)} đ',
                    style: _currencyStyle),
              ],
            ),
            if (widget.orderCode != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mã đơn PayOS'),
                  SelectableText(widget.orderCode!,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWebSection(ThemeData theme, double maxHeight) {
    final controller = _webController;
    if (_webFailed || controller == null) {
      return _buildWebError(theme);
    }
    // Tăng tỷ lệ chiều cao để QR PayOS hiển thị rộng, dễ quét hơn
    final double webHeight = (maxHeight * 0.7).clamp(380, 520);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Thanh toán trực tuyến qua PayOS / OCB',
                style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: webHeight,
            width: double.infinity,
            child: WebViewWidget(controller: controller),
          ),
        ),
      ],
    );
  }

  Widget _buildWebError(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Không tải được PayOS WebView',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          const Text(
              'Nhấn vào icon mở trình duyệt ở góc phải trên để thanh toán bên ngoài.'),
        ],
      ),
    );
  }

  Widget _buildQrSection(ThemeData theme) {
    // Nếu PayOS không trả QR riêng, chỉ hiển thị hướng dẫn dùng QR trong WebView
    if (_qrBytes == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Vui lòng dùng QR ở phần \"Thanh toán trực tuyến\" phía trên để quét bằng ứng dụng ngân hàng.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hoặc quét QR chuyển khoản',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: Image.memory(_qrBytes!,
                  height: 220, width: 220, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Text(
              'Sau khi chuyển khoản, bấm "Kiểm tra trạng thái" để hệ thống cập nhật.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme) {
    if (_isPaid) {
      return Card(
        color: Colors.green.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage ?? 'Thanh toán thành công.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.green[800], fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_statusMessage == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(_statusMessage!)),
          ],
        ),
      ),
    );
  }
}


