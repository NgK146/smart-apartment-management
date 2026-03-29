import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import 'chat_models.dart';
import 'chat_service.dart';
import 'signalr_service.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const SupportTicketDetailScreen({super.key, required this.ticketId});

  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final SupportService _api = SupportService();
  SupportTicketDetail? _ticket;
  List<SupportMessage> _messages = [];
  bool _loading = true;
  String? _error;

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  StreamSubscription<SupportMessage>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messageSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getTicketDetail(widget.ticketId);
      setState(() {
        _ticket = detail;
        _messages = detail.messages;
        _loading = false;
      });
      _scrollToBottom();
      await supportSignalRService.connect();
      await supportSignalRService.joinTicket(widget.ticketId);
      _messageSub ??= supportSignalRService.messageStream.listen((message) {
        if (message.ticketId == widget.ticketId && mounted) {
          setState(() {
            _messages = [..._messages, message];
          });
          _scrollToBottom();
        }
      });
      _statusSub ??= supportSignalRService.statusStream.listen((payload) {
        if (!mounted) return;
        final ticketId = payload['ticketId']?.toString();
        if (ticketId == widget.ticketId) {
          setState(() {
            final status = supportTicketStatusFromString(payload['status']?.toString());
            if (_ticket != null) {
              _ticket = SupportTicketDetail(
                id: _ticket!.id,
                title: _ticket!.title,
                createdById: _ticket!.createdById,
                createdByName: _ticket!.createdByName,
                apartmentCode: _ticket!.apartmentCode,
                status: status,
                createdAt: _ticket!.createdAt,
                updatedAt: DateTime.now(),
                lastMessagePreview: _ticket!.lastMessagePreview,
                lastMessageAt: _ticket!.lastMessageAt,
                assignedToId: payload['assignedToId']?.toString() ?? _ticket!.assignedToId,
                assignedToName: _ticket!.assignedToName,
                category: _ticket!.category,
                messages: _messages,
              );
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Không thể tải chi tiết: $e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isManager = auth.isManagerLike;
    final ticket = _ticket;

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket?.title ?? 'Yêu cầu hỗ trợ'),
        actions: [
          if (isManager && ticket != null)
            PopupMenuButton<SupportTicketStatus>(
              icon: const Icon(Icons.more_vert),
              onSelected: (status) => _updateStatus(status),
              itemBuilder: (context) => SupportTicketStatus.values
                  .map(
                    (status) => PopupMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          if (ticket.status == status) ...[
                            const Icon(Icons.check, size: 16),
                            const SizedBox(width: 8),
                          ],
                          Text(supportTicketStatusToDisplay(status)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
          children: [
                    _TicketHeader(ticket: ticket!, isManager: isManager),
                    const Divider(height: 1),
            Expanded(
                      child: _messages.isEmpty
                          ? const _EmptyMessagesView()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              itemCount: _messages.length,
                              itemBuilder: (_, index) {
                                final message = _messages[index];
                                final isMe = message.senderId == auth.userId;
                                final isStaff = message.isFromStaff;
                                final showAvatar = index == 0 ||
                                    _messages[index - 1].senderId != message.senderId;
                                return _MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  isStaff: isStaff,
                                  showAvatar: showAvatar,
                                );
                              },
                            ),
                    ),
                    _MessageInput(
                      controller: _inputController,
                      focusNode: _focusNode,
                      onSend: _sendMessage,
                    ),
                  ],
                ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    try {
      final message = await _api.sendMessage(widget.ticketId, content);
      setState(() {
        _messages = [..._messages, message];
        _ticket = _ticket == null
            ? null
            : SupportTicketDetail(
                id: _ticket!.id,
                title: _ticket!.title,
                createdById: _ticket!.createdById,
                createdByName: _ticket!.createdByName,
                apartmentCode: _ticket!.apartmentCode,
                status: _ticket!.status,
                createdAt: _ticket!.createdAt,
                updatedAt: DateTime.now(),
                lastMessagePreview: message.content,
                lastMessageAt: message.createdAt,
                assignedToId: _ticket!.assignedToId,
                assignedToName: _ticket!.assignedToName,
                category: _ticket!.category,
                messages: _messages,
              );
      });
      _inputController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi tin nhắn thất bại: $e')),
      );
    }
  }

  Future<void> _updateStatus(SupportTicketStatus status) async {
    try {
      await _api.updateStatus(widget.ticketId, status);
      setState(() {
        if (_ticket != null) {
          _ticket = SupportTicketDetail(
            id: _ticket!.id,
            title: _ticket!.title,
            createdById: _ticket!.createdById,
            createdByName: _ticket!.createdByName,
            apartmentCode: _ticket!.apartmentCode,
            status: status,
            createdAt: _ticket!.createdAt,
            updatedAt: DateTime.now(),
            lastMessagePreview: _ticket!.lastMessagePreview,
            lastMessageAt: _ticket!.lastMessageAt,
            assignedToId: _ticket!.assignedToId,
            assignedToName: _ticket!.assignedToName,
            category: _ticket!.category,
            messages: _messages,
          );
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã cập nhật trạng thái: ${supportTicketStatusToDisplay(status)}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $e')),
      );
    }
  }
}

class _TicketHeader extends StatelessWidget {
  final SupportTicketDetail ticket;
  final bool isManager;
  const _TicketHeader({required this.ticket, required this.isManager});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('HH:mm dd/MM');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: supportTicketStatusToDisplay(ticket.status)),
              if (ticket.apartmentCode?.isNotEmpty == true) _Chip(label: 'Căn hộ ${ticket.apartmentCode}'),
              if (ticket.category?.isNotEmpty == true) _Chip(label: ticket.category!),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tạo bởi: ${ticket.createdByName}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Thời gian: ${df.format(ticket.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
          if (isManager) ...[
            const SizedBox(height: 4),
            Text(
              ticket.assignedToName == null ? 'Chưa gán người xử lý' : 'Người xử lý: ${ticket.assignedToName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final bool isMe;
  final bool isStaff;
  final bool showAvatar;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isStaff,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isMe
        ? theme.colorScheme.primary
        : isStaff
            ? theme.colorScheme.secondaryContainer
            : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final df = DateFormat('HH:mm dd/MM');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showAvatar)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    df.format(message.createdAt),
                    style: TextStyle(
                      color: (isMe ? Colors.white70 : Colors.grey[600]),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
      children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.send,
                  maxLines: null,
                  onSubmitted: onSend,
                  decoration: InputDecoration(
                    hintText: 'Nhập phản hồi...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: () => onSend(controller.text),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessagesView extends StatelessWidget {
  const _EmptyMessagesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.support_agent, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Chưa có phản hồi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy mô tả vấn đề của bạn để Ban quản lý hỗ trợ nhé!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
