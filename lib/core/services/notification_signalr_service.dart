import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../config/config_url.dart';
import '../storage/secure_storage.dart';

class NotificationSignalRService {
  HubConnection? _hub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _starting = false;
  bool _connected = false;

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected || _starting) return;
    _starting = true;
    final token = await SecureTokens.get();
    final base = AppConfig.apiBaseUrl;
    final hubUrl = '${base.replaceAll(RegExp(r'/+$'), '')}/hubs/notifications';

    final options = HttpConnectionOptions(
      accessTokenFactory: () async => token ?? '',
      transport: HttpTransportType.LongPolling,
    );

    _hub = HubConnectionBuilder()
        .withUrl(hubUrl, options: options)
        .withAutomaticReconnect()
        .build();

    _hub!.on('userNotification', (args) {
      if (args == null || args.isEmpty) return;
      final obj = args.first;
      if (obj is Map) {
        final map = obj.map((key, value) => MapEntry(key.toString(), value));
        _controller.add(map);
      }
    });

    try {
      await _hub!.start();
      _connected = true;
    } finally {
      _starting = false;
    }
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _connected = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}

final notificationSignalRService = NotificationSignalRService();


