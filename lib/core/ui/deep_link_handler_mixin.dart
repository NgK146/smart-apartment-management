import  'dart:async';
import 'package:flutter/material.dart';
import '../services/deep_link_service.dart';

/// Mixin để xử lý deep links trong app
mixin DeepLinkHandler<T extends StatefulWidget> on State<T> {
  StreamSubscription<Uri>? _deepLinkSub;
  
  /// Override trong widget để xử lý deep link
  void handleDeepLink(Uri uri);
  
  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }
  
  void _initDeepLinkListener() {
    _deepLinkSub = deepLinkService.deepLinkStream.listen((uri) {
      if (mounted) {
        handleDeepLink(uri);
      }
    });
  }
  
  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }
  
  /// Helper để parse payment result từ deep link
  Map<String, String?> parsePaymentDeepLink(Uri uri) {
    // Format: icitizen://payment/success?orderCode=123&invoiceId=abc
    final path = uri.pathSegments.join('/');
    final result = uri.queryParameters['result'] ?? 
                   (path.contains('success') ? 'success' : 
                    path.contains('failed') ? 'failed' : 
                    path.contains('cancelled') ? 'cancelled' : null);
    final orderCode = uri.queryParameters['orderCode'];
    final invoiceId = uri.queryParameters['invoiceId'];
    
    return {
      'result': result,
      'orderCode': orderCode,
      'invoiceId': invoiceId,
    };
  }
}
