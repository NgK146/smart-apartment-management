import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/concierge_service.dart';
import '../../core/api_client.dart';
import '../../core/services/concierge_service.dart';
import '../../core/ui/snackbar.dart';

class ConciergePage extends StatefulWidget {
  const ConciergePage({super.key});

  @override
  State<ConciergePage> createState() => _ConciergePageState();
}

class _ConciergePageState extends State<ConciergePage> {
  final _conciergeService = ConciergeApiService(api.dio);
  final List<ConciergeService> _services = [
    ConciergeService(
      id: '1',
      name: 'Dọn phòng',
      description: 'Dọn dẹp căn hộ chuyên nghiệp',
      icon: '🧹',
      category: ServiceCategory.housekeeping,
      estimatedMinutes: 60,
    ),
    ConciergeService(
      id: '2',
      name: 'Giặt ủi',
      description: 'Dịch vụ giặt ủi tại nhà',
      icon: '👔',
      category: ServiceCategory.laundry,
      estimatedMinutes: 120,
    ),
    ConciergeService(
      id: '3',
      name: 'Sửa chữa',
      description: 'Sửa chữa điện nước, thiết bị',
      icon: '🔧',
      category: ServiceCategory.maintenance,
      estimatedMinutes: 90,
    ),
    ConciergeService(
      id: '4',
      name: 'Gọi taxi',
      description: 'Đặt xe taxi nhanh chóng',
      icon: '🚕',
      category: ServiceCategory.transportation,
      estimatedMinutes: 15,
    ),
    ConciergeService(
      id: '5',
      name: 'Bảo vệ',
      description: 'Yêu cầu hỗ trợ bảo vệ',
      icon: '🛡️',
      category: ServiceCategory.security,
      estimatedMinutes: 5,
    ),
    ConciergeService(
      id: '6',
      name: 'Lễ tân',
      description: 'Liên hệ lễ tân 24/7',
      icon: '🏨',
      category: ServiceCategory.concierge,
      estimatedMinutes: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dịch vụ Concierge',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header với banner
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.support_agent, size: 40, color: Colors.white),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dịch vụ 5 sao',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Luôn sẵn sàng phục vụ bạn 24/7',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Danh sách dịch vụ
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return _ServiceCard(
                    service: service,
                    conciergeService: _conciergeService,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ConciergeService service;
  final ConciergeApiService conciergeService;

  const _ServiceCard({
    required this.service,
    required this.conciergeService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _showServiceDialog(context, service, conciergeService),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    service.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                service.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (service.estimatedMinutes != null)
                Text(
                  '~${service.estimatedMinutes} phút',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceDialog(BuildContext context, ConciergeService service, ConciergeApiService conciergeService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ServiceRequestSheet(
        service: service,
        conciergeService: conciergeService,
      ),
    );
  }
}

class _ServiceRequestSheet extends StatefulWidget {
  final ConciergeService service;
  final ConciergeApiService conciergeService;

  const _ServiceRequestSheet({
    required this.service,
    required this.conciergeService,
  });

  @override
  State<_ServiceRequestSheet> createState() => _ServiceRequestSheetState();
}

class _ServiceRequestSheetState extends State<_ServiceRequestSheet> {
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Service info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.service.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service.name,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.service.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description field
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Mô tả yêu cầu (tùy chọn)',
                hintText: 'Ví dụ: Dọn phòng vào sáng mai, cần giặt áo sơ mi...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Gửi yêu cầu',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả yêu cầu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Gửi yêu cầu đến API - sẽ ở trạng thái pending chờ admin duyệt
      await widget.conciergeService.createRequest(
        serviceId: widget.service.id,
        serviceName: widget.service.name,
        notes: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      Navigator.pop(context);

      showSnack(
        context,
        'Đã gửi yêu cầu ${widget.service.name}. Vui lòng chờ admin duyệt.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      String msg = 'Không gửi được yêu cầu. Vui lòng thử lại sau.';
      // 404: backend chưa triển khai hoặc sai đường dẫn
      if (e.response?.statusCode == 404) {
        msg =
            'Dịch vụ concierge hiện chưa được kích hoạt trên hệ thống. Vui lòng liên hệ Ban quản lý.';
      }

      showSnack(context, msg, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showSnack(
        context,
        'Không gửi được yêu cầu. Vui lòng kiểm tra kết nối và thử lại.',
        error: true,
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}



