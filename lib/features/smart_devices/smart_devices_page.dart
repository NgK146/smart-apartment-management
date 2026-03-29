import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models/smart_device.dart';

class SmartDevicesPage extends StatefulWidget {
  const SmartDevicesPage({super.key});

  @override
  State<SmartDevicesPage> createState() => _SmartDevicesPageState();
}

class _SmartDevicesPageState extends State<SmartDevicesPage> {
  int _selectedTab = 0; // 0: Barrier, 1: Locker, 2: EV Charging

  final List<SmartBarrier> _barriers = [];
  final List<SmartLocker> _lockers = [];
  final List<EVChargingStation> _evStations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thiết bị thông minh',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Cổng',
              icon: Icons.garage,
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Locker',
              icon: Icons.lock,
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Sạc EV',
              icon: Icons.ev_station,
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildBarriersTab();
      case 1:
        return _buildLockersTab();
      case 2:
        return _buildEVChargingTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chức năng sẽ được kích hoạt khi tích hợp thiết bị thực tế.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarriersTab() {
    if (_barriers.isEmpty) {
      return _buildEmptyState('Chưa có dữ liệu cổng thông minh', Icons.garage_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _barriers.length,
      itemBuilder: (context, index) {
        final barrier = _barriers[index];
        return _BarrierCard(barrier: barrier);
      },
    );
  }

  Widget _buildLockersTab() {
    if (_lockers.isEmpty) {
      return _buildEmptyState('Chưa có dữ liệu locker thông minh', Icons.lock_outline);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lockers.length,
      itemBuilder: (context, index) {
        final locker = _lockers[index];
        return _LockerCard(locker: locker);
      },
    );
  }

  Widget _buildEVChargingTab() {
    if (_evStations.isEmpty) {
      return _buildEmptyState('Chưa có dữ liệu trạm sạc EV', Icons.ev_station_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _evStations.length,
      itemBuilder: (context, index) {
        final station = _evStations[index];
        return _EVStationCard(station: station);
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarrierCard extends StatelessWidget {
  final SmartBarrier barrier;

  const _BarrierCard({required this.barrier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  child: Icon(
                    Icons.garage,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barrier.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        barrier.location,
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
                    color: barrier.status == BarrierStatus.normal
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    barrier.status == BarrierStatus.normal ? 'Bình thường' : 'Bảo trì',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: barrier.status == BarrierStatus.normal
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (barrier.lastAccessAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Lần cuối: ${barrier.lastAccessBy} - ${_formatTime(barrier.lastAccessAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showBarrierQR(context, barrier),
                icon: const Icon(Icons.qr_code),
                label: const Text('Xem QR vào'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _showBarrierQR(BuildContext context, SmartBarrier barrier) {
    showDialog(
      context: context,
      builder: (context) => _QRCodeDialog(
        title: barrier.name,
        qrCode: 'BARRIER_${barrier.id}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }
}

class _LockerCard extends StatelessWidget {
  final SmartLocker locker;

  const _LockerCard({required this.locker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = locker.isAvailable;

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
                  child: Icon(
                    Icons.lock,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locker.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        locker.location,
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
                    color: isAvailable ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAvailable ? 'Trống' : 'Đang dùng',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Kích thước: ${_getSizeLabel(locker.size)}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
            if (!isAvailable && locker.otpCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_open, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Mã OTP: ${locker.otpCode}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isAvailable
                  ? FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('Đặt locker'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _showLockerQR(context, locker),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Xem QR mở'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSizeLabel(LockerSize size) {
    switch (size) {
      case LockerSize.small:
        return 'Nhỏ (<30cm)';
      case LockerSize.medium:
        return 'Vừa (30-50cm)';
      case LockerSize.large:
        return 'Lớn (>50cm)';
    }
  }

  void _showLockerQR(BuildContext context, SmartLocker locker) {
    if (locker.otpCode == null) return;
    showDialog(
      context: context,
      builder: (context) => _QRCodeDialog(
        title: locker.name,
        qrCode: locker.otpCode!,
      ),
    );
  }
}

class _EVStationCard extends StatelessWidget {
  final EVChargingStation station;

  const _EVStationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = station.isAvailable;
    final isCharging = station.isCharging;

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
                  child: Icon(
                    Icons.ev_station,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        station.location,
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
                    color: isAvailable
                        ? Colors.green.shade100
                        : isCharging
                            ? Colors.blue.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAvailable
                        ? 'Trống'
                        : isCharging
                            ? 'Đang sạc'
                            : 'Bảo trì',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isAvailable
                          ? Colors.green.shade700
                          : isCharging
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.bolt, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Loại: ${station.type == ChargingType.fast ? "Sạc nhanh" : "Sạc chậm"}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                if (station.costPerKwh != null) ...[
                  const Spacer(),
                  Text(
                    '${station.costPerKwh!.toStringAsFixed(0)}₫/kWh',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            if (isCharging) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Công suất hiện tại',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        Text(
                          '${station.currentPower} kW',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (station.totalEnergy != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng năng lượng',
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                          Text(
                            '${station.totalEnergy!.toStringAsFixed(1)} kWh',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isAvailable
                  ? FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.power),
                      label: const Text('Đặt slot sạc'),
                    )
                  : OutlinedButton(
                      onPressed: () {},
                      child: const Text('Xem chi tiết'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String title;
  final String qrCode;

  const _QRCodeDialog({
    required this.title,
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
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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



