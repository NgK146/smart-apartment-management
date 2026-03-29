import 'dart:async';

import 'package:icitizen_app/config/config_url.dart';
import 'package:icitizen_app/core/storage/secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'chat_models.dart';

class SupportSignalRService {
  HubConnection? _hub;
  bool _connected = false;
  final _messageController = StreamController<SupportMessage>.broadcast();
  final _ticketCreatedController = StreamController<SupportTicket>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SupportMessage> get messageStream => _messageController.stream;
  Stream<SupportTicket> get ticketCreatedStream => _ticketCreatedController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  bool _starting = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (isConnected || _starting) return;
    _starting = true;

    final token = await SecureTokens.get();
    final base = AppConfig.apiBaseUrl;
    final hubUrl = '${base.replaceAll(RegExp(r'/+$'), '')}/hubs/support';

    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: () async => token ?? '',
      transport: HttpTransportType.LongPolling,
    );

    _hub = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: httpOptions,
        )
        .withAutomaticReconnect()
        .build();

    _hub!.on('TicketMessage', (args) {
      if (args == null || args.isEmpty) return;
      final obj = args.first;
      final map = _normalizeMap(obj);
      if (map != null) {
        _messageController.add(SupportMessage.fromJson(map));
      }
    });

    _hub!.on('TicketCreated', (args) {
      if (args == null || args.isEmpty) return;
      final obj = args.first;
      final map = _normalizeMap(obj);
      if (map != null) {
        _ticketCreatedController.add(SupportTicket.fromJson(map));
      }
    });

    _hub!.on('TicketStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      final obj = args.first;
      final map = _normalizeMap(obj);
      if (map != null) {
        _statusController.add(map);
      }
    });

    _hub!.on('TicketAssigned', (args) {
      if (args == null || args.isEmpty) return;
      final obj = args.first;
      final map = _normalizeMap(obj);
      if (map != null) {
        _statusController.add(map);
      }
    });

    try {
      await _hub!.start();
      _connected = true;
    } catch (e) {
      _connected = false;
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> joinTicket(String ticketId) async {
    if (!isConnected) {
      await connect();
    }
    try {
      await _hub!.invoke('JoinTicket', args: [ticketId]);
    } catch (_) {
      // ignore
    }
  }

  Future<void> dispose() async {
    await _hub?.stop();
    _connected = false;
    await _messageController.close();
    await _ticketCreatedController.close();
    await _statusController.close();
  }

  Map<String, dynamic>? _normalizeMap(Object? source) {
    if (source is Map<String, dynamic>) return source;
    if (source is Map) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

final supportSignalRService = SupportSignalRService();

