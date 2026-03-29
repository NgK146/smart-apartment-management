import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'amenities_service.dart';
import 'amenity_booking_model.dart';

class AmenityBookingDetailPage extends StatefulWidget {
  final String bookingId;
  const AmenityBookingDetailPage({super.key, required this.bookingId});

  @override
  State<AmenityBookingDetailPage> createState() => _AmenityBookingDetailPageState();
}

class _AmenityBookingDetailPageState extends State<AmenityBookingDetailPage> {
  final _svc = AmenitiesService();
  AmenityBookingModel? _booking;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await _svc.getBooking(widget.bookingId);
      if (mounted) setState(() => _booking = b);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đặt tiện ích')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lỗi: $_error'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('Thử lại'))
                    ],
                  ),
                )
              : _booking == null
                  ? const Center(child: Text('Không tìm thấy đặt lịch'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_booking!.amenityName, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          _row('Trạng thái', _booking!.status),
                          _row('Bắt đầu', _fmt(_booking!.startTimeUtc)),
                          _row('Kết thúc', _fmt(_booking!.endTimeUtc)),
                          if (_booking!.price != null) _row('Giá', NumberFormat('#,##0').format(_booking!.price)),
                          if (_booking!.invoiceId != null) _row('Hoá đơn', _booking!.invoiceId!),
                        ],
                      ),
                    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
}


