import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../config/config_url.dart';
import '../auth/auth_provider.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _communityApi = CommunityChatService();
  final _messages = <CommunityMessageModel>[];
  final _messageIds = <String>{};
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  // final _recorder = AudioRecorder(); // Tạm thời comment để tránh lỗi build
  final _audioPlayer = AudioPlayer();
  final String _room = 'general';

  HubConnection? _hub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _loading = true;
  bool _sending = false;
  // bool _isRecording = false; // Tạm thời comment
  String? _error;
  String? _playingMessageId;
  // DateTime? _recordingStart; // Tạm thời comment
  // String? _recordingPath; // Tạm thời comment

  @override
  void initState() {
    super.initState();
    _init();
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        if (mounted) setState(() => _playingMessageId = null);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _connectionMonitorTimer?.cancel();
    final hub = _hub;
    if (hub != null && hub.state == HubConnectionState.Connected) {
      hub.invoke('LeaveRoom', args: <Object>[_room]).ignore();
    }
    _hub?.stop();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    // _recorder.dispose(); // Tạm thời comment
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _loadHistory();
      await _connect();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    final data = await _communityApi.fetchMessages(room: _room, limit: 100);
    if (!mounted) return;
    data.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() {
      _messages
        ..clear()
        ..addAll(data);
      _messageIds
        ..clear()
        ..addAll(data.map((e) => e.id));
    });
    _scrollToBottom();
  }

  Future<void> _connect() async {
    final auth = context.read<AuthState>();
    final url = '${AppConfig.apiBaseUrl}/hubs/community';

    final hub = HubConnectionBuilder()
        .withUrl(
          url,
          options: HttpConnectionOptions(
      accessTokenFactory: () async => auth.token ?? '',
            transport: HttpTransportType.LongPolling,
            logger: null, // Tắt log để giảm noise
          ),
        )
        .withAutomaticReconnect(
          retryDelays: const [3000, 5000, 10000, 20000], // milliseconds - tăng số lần retry
        )
        .build();

    // Lắng nghe connection state changes thông qua state stream
    // Note: signalr_netcore có thể không có onclose callback, dùng state monitoring thay thế

    hub.on("message", (args) {
      if (args == null || args.isEmpty) return;
      final map = _normalizeMap(args.first);
      if (map == null) return;
      final model = CommunityMessageModel.fromJson(map);
      if (_messageIds.contains(model.id)) return;
      _messageIds.add(model.id);
      if (!mounted) return;
      setState(() {
        _messages.add(model);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();
    });

    try {
      // Tăng timeout lên 15 giây cho ngrok (có thể chậm)
      await (hub.start() as Future<void>).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Kết nối SignalR quá lâu. Sẽ thử lại sau.');
        },
      );
      await (hub.invoke("JoinRoom", args: <Object>[_room]) as Future).timeout(
        const Duration(seconds: 5),
      );
      if (!mounted) return;
      setState(() => _hub = hub);
      // Dừng polling nếu đang chạy (SignalR đã kết nối thành công)
      _pollingTimer?.cancel();
      print('SignalR connected successfully');
      // Bắt đầu monitor connection state
      _startConnectionMonitoring();
    } catch (e) {
      print('SignalR connection failed: $e');
      if (mounted) {
        setState(() => _hub = hub); // Vẫn lưu hub để retry sau
        _startPollingFallback();
        // Thử reconnect sau 10 giây
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && _hub?.state != HubConnectionState.Connected) {
            _retrySignalRConnection();
          }
        });
        // Chỉ hiển thị warning nhẹ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang kết nối realtime... Sẽ cập nhật định kỳ nếu không kết nối được.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Timer? _connectionMonitorTimer;
  void _startConnectionMonitoring() {
    _connectionMonitorTimer?.cancel();
    // Monitor connection state mỗi 5 giây
    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _hub == null) {
        _connectionMonitorTimer?.cancel();
        return;
      }
      final state = _hub!.state;
      if (state != HubConnectionState.Connected) {
        print('SignalR connection lost, state: $state');
        // Nếu mất kết nối, start polling fallback
        if (_pollingTimer == null || !_pollingTimer!.isActive) {
          _startPollingFallback();
        }
        // Thử reconnect sau 10 giây nếu chưa connected
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && _hub?.state != HubConnectionState.Connected) {
            _retrySignalRConnection();
          }
        });
      } else {
        // Nếu đã connected, dừng polling
        _pollingTimer?.cancel();
      }
    });
  }

  Future<void> _retrySignalRConnection() async {
    if (_hub == null || !mounted) return;
    if (_hub!.state == HubConnectionState.Connected) {
      _pollingTimer?.cancel();
      return;
    }
    try {
      print('Retrying SignalR connection...');
      await (_hub!.start() as Future<void>).timeout(
        const Duration(seconds: 10),
      );
      await (_hub!.invoke("JoinRoom", args: <Object>[_room]) as Future).timeout(
        const Duration(seconds: 3),
      );
      if (mounted && _hub!.state == HubConnectionState.Connected) {
        _pollingTimer?.cancel();
        print('SignalR reconnected successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã kết nối realtime thành công!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('SignalR retry failed: $e');
      // Tiếp tục dùng polling
    }
  }

  Timer? _pollingTimer;
  void _startPollingFallback() {
    _pollingTimer?.cancel();
    // Chỉ start polling nếu SignalR không connected
    if (_hub?.state == HubConnectionState.Connected) {
      return;
    }
    // Poll mỗi 5 giây để lấy tin nhắn mới (giảm tần suất để tiết kiệm tài nguyên)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) {
        _pollingTimer?.cancel();
        return;
      }
      // Nếu SignalR đã kết nối, dừng polling
      if (_hub?.state == HubConnectionState.Connected) {
        _pollingTimer?.cancel();
        print('Stopped polling - SignalR is now connected');
        return;
      }
      try {
        final lastTime = _messages.isEmpty
            ? DateTime.now().subtract(const Duration(hours: 1))
            : _messages.last.createdAt;
        final newMessages = await _communityApi.fetchMessages(
          room: _room,
          limit: 50,
          after: lastTime,
        );
        if (newMessages.isEmpty || !mounted) return;
        setState(() {
          for (final msg in newMessages) {
            if (!_messageIds.contains(msg.id)) {
              _messageIds.add(msg.id);
              _messages.add(msg);
            }
          }
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      } catch (e) {
        print('Polling error: $e');
        // Nếu polling fail liên tục, có thể thử reconnect SignalR
      }
    });
  }

  Future<void> _sendText() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    setState(() => _sending = true);
    final text = content;
    _input.clear();
    try {
      await _communityApi.sendMessage(room: _room, content: text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi tin thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);
    try {
      await _communityApi.sendMessage(
        room: _room,
        attachmentType: 'image',
        fileBase64: base64,
        fileName: p.basename(image.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi ảnh thất bại: $e')),
        );
      }
    }
  }

  // Tạm thời comment để tránh lỗi build với package record
  /*
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ứng dụng chưa có quyền ghi âm.')),
      );
      return;
    }
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath = p.join(
        Directory.systemTemp.path,
        'community_${DateTime.now().millisecondsSinceEpoch}.m4a',
      ),
    );
    setState(() {
      _isRecording = true;
      _recordingStart = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    final filePath = path ?? _recordingPath;
    _recordingPath = null;
    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final duration = _recordingStart == null
        ? null
        : DateTime.now().difference(_recordingStart!).inMilliseconds / 1000.0;
    try {
      await _communityApi.sendMessage(
        room: _room,
        attachmentType: 'audio',
        fileBase64: base64,
        fileName: p.basename(filePath),
        durationSeconds: duration,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi ghi âm thất bại: $e')),
        );
      }
    }
    try {
      await file.delete();
    } catch (_) {}
  }
  */

  Future<void> _togglePlayAudio(CommunityMessageModel message) async {
    final url = message.attachmentUrl == null ? null : AppConfig.resolve(message.attachmentUrl!);
    if (url == null) return;
    try {
      if (_playingMessageId == message.id) {
        await _audioPlayer.stop();
        setState(() => _playingMessageId = null);
        return;
      }
      await _audioPlayer.setUrl(url);
      setState(() => _playingMessageId = message.id);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không phát được file âm thanh: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final currentUserId = auth.userId;
    final df = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat cộng đồng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            }
          },
          tooltip: 'Quay lại',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Lỗi: $_error'))
              : Column(
                  children: [
                    // Tạm thời comment phần voice recording UI
                    /*
                    if (_isRecording)
                      Container(
                        width: double.infinity,
                        color: Colors.red.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.mic, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Đang ghi âm... nhấn lại để dừng'),
                          ],
                        ),
                      ),
                    */
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(child: Text('Chưa có tin nhắn nào'))
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final m = _messages[i];
                                final isMe = currentUserId != null && currentUserId == m.senderId;
                                final isPlaying = _playingMessageId == m.id;
                                return _CommunityMessageBubble(
                                  message: m,
                                  isMine: isMe,
                                  timeLabel: df.format(m.createdAt.toLocal()),
                                  onPlayAudio: m.attachmentType == 'audio'
                                      ? () => _togglePlayAudio(m)
                                      : null,
                                  isAudioPlaying: isPlaying,
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo),
                              tooltip: 'Gửi ảnh',
                            ),
                            // Tạm thời comment nút voice recording
                            /*
                            IconButton(
                              onPressed: _toggleRecording,
                              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                              color: _isRecording ? Colors.red : null,
                              tooltip: _isRecording ? 'Dừng ghi âm' : 'Ghi âm',
                            ),
                            */
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendText(),
                                decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton.small(
                              heroTag: 'send',
                              onPressed: _sending ? null : _sendText,
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Map<String, dynamic>? _normalizeMap(Object? source) {
    if (source is Map<String, dynamic>) return source;
    if (source is Map) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

class _CommunityMessageBubble extends StatelessWidget {
  const _CommunityMessageBubble({
    required this.message,
    required this.isMine,
    required this.timeLabel,
    this.onPlayAudio,
    this.isAudioPlaying = false,
  });

  final CommunityMessageModel message;
  final bool isMine;
  final String timeLabel;
  final VoidCallback? onPlayAudio;
  final bool isAudioPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isMine ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(color: textColor),
              ),
              if (message.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.content,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ],
              if (message.attachmentType == 'image' && message.attachmentUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    AppConfig.resolve(message.attachmentUrl!),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      width: 160,
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ],
              if (message.attachmentType == 'audio' && onPlayAudio != null) ...[
                const SizedBox(height: 8),
                _AudioBubble(
                  isPlaying: isAudioPlaying,
                  onPressed: onPlayAudio!,
                  durationLabel: message.attachmentDurationSeconds != null
                      ? _formatDuration(message.attachmentDurationSeconds!)
                      : 'Audio',
                  color: textColor,
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  timeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _AudioBubble extends StatelessWidget {
  const _AudioBubble({
    required this.isPlaying,
    required this.onPressed,
    required this.durationLabel,
    required this.color,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final String durationLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            color: color,
          ),
                  const SizedBox(width: 8),
          Text(
            durationLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
