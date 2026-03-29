import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import 'conversation_list_bloc.dart';
import 'chat_models.dart';
import 'chat_service.dart';
import 'chat_screen.dart'; // SupportTicketDetailScreen
import 'new_ticket_screen.dart';
import 'signalr_service.dart';

class SupportTicketListScreen extends StatefulWidget {
  const SupportTicketListScreen({super.key});

  @override
  State<SupportTicketListScreen> createState() => _SupportTicketListScreenState();
}

class _SupportTicketListScreenState extends State<SupportTicketListScreen> {
  SupportTicketStatus? _filterStatus;
  final _searchController = TextEditingController();
  StreamSubscription<SupportTicket>? _ticketSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _initSignalR();
  }

  @override
  void dispose() {
    _ticketSub?.cancel();
    _statusSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // [THÊM MỚI] Header cong với Floating Filters
  Widget _buildHeader(BuildContext context, bool isManager) {
    final ticketsPending = 0; // Giả định tính toán từ BLoC state nếu cần

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Gradient
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 10, 80), // 80 bottom cho floating filters
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isManager ? 'Quản lý Ticket' : 'Kênh hỗ trợ', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Hỗ trợ cư dân', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (isManager)
                        Text('Ticket chờ xử lý: $ticketsPending', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  // Nút Refresh
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: () => _applyFilter(context),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Floating Search & Dropdown Filters
        Positioned(
          bottom: -25,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Tìm theo tiêu đề/căn hộ...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _applyFilter(context),
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown Filter
                DropdownButton<SupportTicketStatus?>(
                  value: _filterStatus,
                  hint: const Text('Tất cả'),
                  icon: const Icon(Icons.filter_list, size: 20),
                  underline: const SizedBox.shrink(),
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                    _applyFilter(context);
                  },
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả')),
                    for (final status in SupportTicketStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(supportTicketStatusToDisplay(status)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isManager = auth.isManagerLike;

    return BlocProvider(
      create: (_) => SupportTicketListBloc(SupportService())..add(LoadSupportTickets()),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        // [XÓA] Xóa AppBar cũ và dùng Header tùy chỉnh
        body: Column(
          children: [
            // 1. HEADER & FLOATING FILTERS
            _buildHeader(context, isManager),

            // 2. TICKET LIST (Bọc trong Expanded)
            Expanded(
              // Thêm Padding trên để bù cho Floating Search Bar
              child: Padding(
                padding: const EdgeInsets.only(top: 30),
                child: BlocBuilder<SupportTicketListBloc, SupportTicketListState>(
                  builder: (context, state) {
                    if (state is SupportTicketListLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is SupportTicketListError) {
                      return Center(child: Text(state.message));
                    }
                    if (state is SupportTicketListLoaded) {
                      if (state.tickets.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.support_agent, size: 64),
                              const SizedBox(height: 8),
                              Text('Chưa có yêu cầu hỗ trợ', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                isManager
                                    ? 'Cư dân chưa gửi yêu cầu nào.'
                                    : 'Nhấn nút + để tạo yêu cầu hỗ trợ mới.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => _applyFilter(context),
                        child: ListView.separated(
                          itemCount: state.tickets.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final ticket = state.tickets[i];
                            final subtitleParts = <String>[];
                            final ticketStatus = supportTicketStatusToDisplay(ticket.status);
                            final df = DateFormat('dd/MM HH:mm');

                            if (ticket.apartmentCode?.isNotEmpty == true) {
                              subtitleParts.add('Căn hộ: ${ticket.apartmentCode}');
                            }
                            subtitleParts.add('Trạng thái: $ticketStatus');
                            if (ticket.lastMessageAt != null) {
                              subtitleParts.add('Cập nhật: ${df.format(ticket.lastMessageAt!)}');
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                              leading: Icon(Icons.comment_outlined, color: ticket.statusColor),
                              title: Text(ticket.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subtitleParts.join(' • '), style: Theme.of(context).textTheme.bodySmall),
                                  if (ticket.lastMessagePreview?.isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        ticket.lastMessagePreview!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isManager && ticket.assignedToName != null
                                  ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Icon(Icons.person, size: 16),
                                  Text(ticket.assignedToName!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                                ],
                              )
                                  : null,
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => SupportTicketDetailScreen(ticketId: ticket.id),
                                ));
                                if (!mounted) return;
                                _applyFilter(context);
                              },
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: isManager
            ? null
            : FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewTicketScreen()),
            );
            if (created == true && mounted) {
              _applyFilter(context);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Yêu cầu mới'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _applyFilter(BuildContext context) async {
    context.read<SupportTicketListBloc>().add(
      LoadSupportTickets(
        status: _filterStatus,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      ),
    );
  }

  Future<void> _initSignalR() async {
    await supportSignalRService.connect();
    _ticketSub ??= supportSignalRService.ticketCreatedStream.listen((ticket) {
      final authState = context.read<AuthState>();
      final isStaff = authState.isManagerLike;
      if (!isStaff && ticket.createdById != authState.userId) return;
      _applyFilter(context);
    });
    _statusSub ??= supportSignalRService.statusStream.listen((payload) {
      final authState = context.read<AuthState>();
      final isStaff = authState.isManagerLike;
      final ticketId = payload['ticketId']?.toString();
      if (!isStaff && payload['createdById'] != null && payload['createdById'] != authState.userId) {
        return;
      }
      if (ticketId != null) {
        _applyFilter(context);
      }
    });
  }
}

// Giả định các helper sau tồn tại trong chat_models.dart hoặc tương tự
// Cần thiết để code có thể chạy và hiển thị đúng màu sắc

extension SupportTicketColorExtension on SupportTicket {
  Color get statusColor {
    switch (status) {
      case SupportTicketStatus.newTicket:
        return Colors.orange;
      case SupportTicketStatus.inProgress:
        return Colors.blue;
      case SupportTicketStatus.resolved:
        return Colors.green;
      case SupportTicketStatus.closed:
        return Colors.grey;
    }
  }
}