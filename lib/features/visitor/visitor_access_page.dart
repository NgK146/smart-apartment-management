import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api_client.dart';
import '../../core/services/visitor_service.dart';
import 'models/visitor_access.dart';

class VisitorAccessPage extends StatefulWidget {
  const VisitorAccessPage({super.key});

  @override
  State<VisitorAccessPage> createState() => _VisitorAccessPageState();
}

class _VisitorAccessPageState extends State<VisitorAccessPage> {
  final _visitorService = VisitorService(api.dio);
  List<VisitorAccess> _visitors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      _visitors = await _visitorService.getMyVisitors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải danh sách: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quản lý khách',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _buildHistoryTab(),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_visitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có khách nào',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisitors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visitors.length,
        itemBuilder: (context, index) {
          final visitor = _visitors[index];
          return _VisitorCard(
            visitor: visitor,
            onRefresh: _loadVisitors,
          );
        },
      ),
    );
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String qrCode;
  final String visitorName;
  final VisitorAccess? visitorAccess;

  const _QRCodeDialog({
    required this.qrCode,
    required this.visitorName,
    this.visitorAccess,
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
              'QR Code đã tạo',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cho: $visitorName',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: Share QR code
                      Navigator.pop(context);
                    },
                    child: const Text('Chia sẻ'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final VisitorAccess visitor;
  final VoidCallback? onRefresh;

  const _VisitorCard({
    required this.visitor,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(visitor.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.visitorName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (visitor.visitorPhone != null)
                        Text(
                          visitor.visitorPhone!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(visitor.status),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${visitor.visitDate.day}/${visitor.visitDate.month}/${visitor.visitDate.year}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                if (visitor.visitTime != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    visitor.visitTime!,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ],
              ],
            ),
            if (visitor.purpose != null) ...[
              const SizedBox(height: 8),
              Text(
                visitor.purpose!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (visitor.canCheckIn)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _QRCodeDialog(
                        qrCode: visitor.qrCode,
                        visitorName: visitor.visitorName,
                        visitorAccess: visitor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Xem QR Code'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AccessStatus status) {
    switch (status) {
      case AccessStatus.pending:
        return Colors.orange;
      case AccessStatus.checkedIn:
        return Colors.green;
      case AccessStatus.checkedOut:
        return Colors.blue;
      case AccessStatus.expired:
        return Colors.red;
      case AccessStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusText(AccessStatus status) {
    switch (status) {
      case AccessStatus.pending:
        return 'Chờ';
      case AccessStatus.checkedIn:
        return 'Đã vào';
      case AccessStatus.checkedOut:
        return 'Đã ra';
      case AccessStatus.expired:
        return 'Hết hạn';
      case AccessStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

