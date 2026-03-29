import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/services/events_service.dart';
import '../../core/ui/snackbar.dart';
import 'models/community_event.dart';

class CommunityEventsPage extends StatefulWidget {
  const CommunityEventsPage({super.key});

  @override
  State<CommunityEventsPage> createState() => _CommunityEventsPageState();
}

class _CommunityEventsPageState extends State<CommunityEventsPage> {
  final _eventsService = EventsService(api.dio);
  int _selectedFilter = 0; // 0: All, 1: Upcoming, 2: My Events
  final _events = <CommunityEvent>[];
  final _myRegistrations = <EventRegistration>[];
  bool _loadingEvents = true;
  bool _loadingRegistrations = false;

  @override
  void initState() {
    super.initState();
    _refreshCurrentFilter();
    _loadMyRegistrations();
  }

  Future<void> _refreshCurrentFilter() async {
    await _loadEvents();
    if (_selectedFilter == 2) {
      await _loadMyRegistrations();
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      EventStatus? statusFilter;
      if (_selectedFilter == 1) statusFilter = EventStatus.upcoming;
      final data = await _eventsService.getEvents(status: statusFilter);
      if (mounted) {
        setState(() {
          _events
            ..clear()
            ..addAll(data);
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải sự kiện: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadMyRegistrations() async {
    if (_loadingRegistrations) return;
    setState(() => _loadingRegistrations = true);
    try {
      final data = await _eventsService.getMyRegistrations();
      if (mounted) {
        setState(() {
          _myRegistrations
            ..clear()
            ..addAll(data);
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải sự kiện của bạn: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingRegistrations = false);
    }
  }

  void _onFilterSelected(int value) {
    if (_selectedFilter == value) return;
    setState(() => _selectedFilter = value);
    _refreshCurrentFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sự kiện cộng đồng',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loadingEvents
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refreshCurrentFilter,
                    child: _buildEventsList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tất cả',
            isSelected: _selectedFilter == 0,
            onTap: () => _onFilterSelected(0),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Sắp tới',
            isSelected: _selectedFilter == 1,
            onTap: () => _onFilterSelected(1),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Của tôi',
            isSelected: _selectedFilter == 2,
            onTap: () => _onFilterSelected(2),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    final filteredEvents = _getFilteredEvents();

    if (filteredEvents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.event, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 2
                    ? 'Bạn chưa đăng ký sự kiện nào'
                    : 'Chưa có sự kiện',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        return _EventCard(
          event: filteredEvents[index],
          onRegister: () => _registerEvent(filteredEvents[index]),
          onCheckIn: () => _showCheckInQR(filteredEvents[index]),
        );
      },
    );
  }

  List<CommunityEvent> _getFilteredEvents() {
    switch (_selectedFilter) {
      case 1:
        return _events.where((e) => e.status == EventStatus.upcoming).toList();
      case 2:
        if (_myRegistrations.isEmpty) return [];
        final ids = _myRegistrations.map((e) => e.eventId).toSet();
        return _events.where((e) => ids.contains(e.id)).toList();
      default:
        return _events;
    }
  }

  Future<void> _registerEvent(CommunityEvent event) async {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng ký tham gia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              event.fee != null && event.fee! > 0
                  ? 'Phí tham gia: ${formatter.format(event.fee)}'
                  : 'Sự kiện miễn phí',
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng ký'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _eventsService.registerEvent(event.id);
      if (!mounted) return;
      showSnack(context, 'Đã đăng ký ${event.title}');
      await _refreshCurrentFilter();
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi đăng ký: $e', error: true);
    }
  }

  void _showCheckInQR(CommunityEvent event) {
    showDialog(
      context: context,
      builder: (context) => _CheckInQRDialog(
        event: event,
        qrCode: event.qrCode ?? 'EVENT_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CommunityEvent event;
  final VoidCallback onRegister;
  final VoidCallback onCheckIn;

  const _EventCard({
    required this.event,
    required this.onRegister,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final isFull = event.isFull;
    final canRegister = event.canRegister;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Center(
              child: Icon(
                _getCategoryIcon(event.category),
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(event.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getCategoryLabel(event.category),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryColor(event.category),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      formatter.format(event.startDate),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      event.location,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      '${event.currentParticipants}/${event.maxParticipants} người',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const Spacer(),
                    if (event.fee != null && event.fee! > 0)
                      Text(
                        '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(event.fee)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Miễn phí',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isFull)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: null,
                      child: const Text('Đã đầy'),
                    ),
                  )
                else if (canRegister)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCheckIn,
                          child: const Text('Check-in'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: onRegister,
                          child: const Text('Đăng ký'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCheckIn,
                      child: const Text('Xem QR Check-in'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return Icons.people;
      case EventCategory.fitness:
        return Icons.fitness_center;
      case EventCategory.education:
        return Icons.school;
      case EventCategory.entertainment:
        return Icons.movie;
      case EventCategory.food:
        return Icons.restaurant;
      case EventCategory.other:
        return Icons.event;
    }
  }

  Color _getCategoryColor(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return Colors.blue;
      case EventCategory.fitness:
        return Colors.orange;
      case EventCategory.education:
        return Colors.purple;
      case EventCategory.entertainment:
        return Colors.pink;
      case EventCategory.food:
        return Colors.red;
      case EventCategory.other:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(EventCategory category) {
    switch (category) {
      case EventCategory.social:
        return 'Xã hội';
      case EventCategory.fitness:
        return 'Thể thao';
      case EventCategory.education:
        return 'Giáo dục';
      case EventCategory.entertainment:
        return 'Giải trí';
      case EventCategory.food:
        return 'Ẩm thực';
      case EventCategory.other:
        return 'Khác';
    }
  }
}

class _CheckInQRDialog extends StatelessWidget {
  final CommunityEvent event;
  final String qrCode;

  const _CheckInQRDialog({
    required this.event,
    required this.qrCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR Check-in',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
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
                data: qrCode,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Quét QR này tại sự kiện để check-in',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }
}



