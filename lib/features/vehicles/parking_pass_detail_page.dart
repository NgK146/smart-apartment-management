import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'parking_pass_model.dart';

// [THÊM MỚI] Màn hình giả lập khi bấm Gia hạn
class RenewPassScreen extends StatelessWidget {
  const RenewPassScreen({super.key, required this.pass});
  final ParkingPassModel pass;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gia hạn vé xe')),
      body: Center(
        child: Text('Giao diện chọn gói và thanh toán cho xe ${pass.vehicleLicensePlate}'),
      ),
    );
  }
}

class ParkingPassDetailPage extends StatelessWidget {
  final ParkingPassModel pass;

  const ParkingPassDetailPage({super.key, required this.pass});

  // Helper để xử lý navigation đến màn hình Gia hạn
  void _navigateToRenew(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RenewPassScreen(pass: pass)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpiringSoon = pass.needsRenewal;
    final isExpiredOrRevoked = pass.status == 'Expired' || pass.status == 'Revoked';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vé xe của tôi'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Thẻ vé chính
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isExpiringSoon
                        ? [Colors.orange.shade400, Colors.orange.shade600]
                        : (isExpiredOrRevoked ? [Colors.grey.shade600, Colors.grey.shade800] : [theme.colorScheme.primary, theme.colorScheme.secondary]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VÉ XE',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pass.vehicleLicensePlate ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (isExpiringSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Sắp hết hạn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // QR Code
                    // Chỉ hiện QR nếu đang hoạt động
                    if (pass.isActive)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: pass.passCode,
                          size: 200,
                          backgroundColor: Colors.white,
                          // Nếu đang hết hạn, mờ QR đi một chút
                          version: QrVersions.auto,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: isExpiringSoon ? Colors.orange.shade800 : Colors.black),
                          dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: isExpiringSoon ? Colors.orange.shade800 : Colors.black),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        width: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block, size: 60, color: Colors.red.shade700),
                            const SizedBox(height: 8),
                            Text(pass.statusText, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Mã vé
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Mã: ${pass.passCode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Thông tin chi tiết
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin vé',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Gói vé', pass.parkingPlanName ?? 'N/A'),
                    _buildInfoRow(context, 'Trạng thái', pass.statusText, statusColor: pass.statusColor),
                    _buildInfoRow(
                      context,
                      'Ngày bắt đầu',
                      '${pass.validFrom.day}/${pass.validFrom.month}/${pass.validFrom.year}',
                    ),
                    _buildInfoRow(
                      context,
                      'Ngày hết hạn',
                      '${pass.validTo.day}/${pass.validTo.month}/${pass.validTo.year}',
                    ),
                    if (pass.daysRemaining > 0)
                      _buildInfoRow(
                        context,
                        'Còn lại',
                        '${pass.daysRemaining} ngày',
                        valueColor: isExpiringSoon ? Colors.orange[700] : Colors.green[700],
                      ),
                    if (pass.revocationReason != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lý do hủy: ${pass.revocationReason}',
                                style: TextStyle(color: Colors.red[700], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isExpiringSoon)
              const SizedBox(height: 16), // Thêm khoảng trống nếu có cảnh báo dưới này
          ],
        ),
      ),
      // [THÊM MỚI] Nút hành động cố định (CTA)
      bottomNavigationBar: isExpiredOrRevoked
          ? null
          : Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
          top: 8,
        ),
        child: FilledButton.icon(
          onPressed: () => _navigateToRenew(context),
          icon: const Icon(Icons.refresh),
          label: Text(isExpiringSoon ? 'GIA HẠN NGAY (${pass.daysRemaining} ngày)' : 'QUẢN LÝ GIA HẠN'),
          style: FilledButton.styleFrom(
            backgroundColor: isExpiringSoon ? Colors.orange : theme.colorScheme.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? statusColor, Color? valueColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? statusColor,
            ),
          ),
        ],
      ),
    );
  }
}