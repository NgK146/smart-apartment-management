import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Service để xử lý deep links từ payment gateways
class DeepLinkService {
  final _appLinks = AppLinks();
  
  /// Stream controller để phát deep links
  final _controller = StreamController<Uri>.broadcast();
  
  /// Stream để listen deep links
  Stream<Uri> get deepLinkStream => _controller.stream;
  
  /// Khởi tạo deep link listener
  Future<void> initialize() async {
    try {
      // Xử lý deep link ban đầu (nếu app được mở từ deep link)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Initial deep link: $initialUri');
        _controller.add(initialUri);
      }
      
      // Listen các deep links sau đó
      _appLinks.uriLinkStream.listen((Uri uri) {
        debugPrint('🔗 Deep link received: $uri');
        _controller.add(uri);
      }, onError: (err) {
        debugPrint('Deep link error: $err');
      });
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }
  
  /// Cleanup
  void dispose() {
    _controller.close();
  }
}

/// Global instance
final deepLinkService = DeepLinkService();
