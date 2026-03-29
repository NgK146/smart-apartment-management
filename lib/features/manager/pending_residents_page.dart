import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../../core/api_client.dart';
import 'package:intl/intl.dart';

class PendingResidentRequest {
  final String id;
  final String userId;
  final String? nationalId;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;
  final String? residentType;
  final int? numResidents;
  final ApartmentInfo? apartment;
  final DateTime createdAtUtc;

  PendingResidentRequest({
    required this.id,
    required this.userId,
    this.nationalId,
    this.phone,
    this.email,
    this.dateJoined,
    this.residentType,
    this.numResidents,
    this.apartment,
    required this.createdAtUtc,
  });

  factory PendingResidentRequest.fromJson(Map<String, dynamic> j) => PendingResidentRequest(
    id: j['id'].toString(),
    userId: j['userId'].toString(),
    nationalId: j['nationalId']?.toString(),
    phone: j['phone']?.toString(),
    email: j['email']?.toString(),
    dateJoined: j['dateJoined'] != null ? DateTime.parse(j['dateJoined']) : null,
    residentType: j['residentType']?.toString(),
    numResidents: j['numResidents'] as int?,
    apartment: j['apartment'] != null ? ApartmentInfo.fromJson(Map<String, dynamic>.from(j['apartment'])) : null,
    createdAtUtc: DateTime.parse(j['createdAtUtc']),
  );
}

class ApartmentInfo {
  final String id;
  final String code;
  final String building;
  final int floor;

  ApartmentInfo({required this.id, required this.code, required this.building, required this.floor});

  factory ApartmentInfo.fromJson(Map<String, dynamic> j) => ApartmentInfo(
    id: j['id'].toString(),
    code: j['code'].toString(),
    building: j['building'].toString(),
    floor: j['floor'] as int? ?? 0,
  );
}

class PendingResidentsPage extends StatefulWidget {
  const PendingResidentsPage({super.key});
  @override
  State<PendingResidentsPage> createState() => _PendingResidentsPageState();
}

class _PendingResidentsPageState extends State<PendingResidentsPage> {
  final _search = TextEditingController();
  List<PendingResidentRequest> _items = [];
  bool _loading = true;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final queryParams = <String, dynamic>{'page': 1, 'pageSize': 100};
      if (_search.text.trim().isNotEmpty) queryParams['search'] = _search.text.trim();
      final res = await api.dio.get('/api/Residents/pending', queryParameters: queryParams);
      final items = (res.data['items'] as List).map((e) => PendingResidentRequest.fromJson(Map<String, dynamic>.from(e))).toList();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải danh sách yêu cầu: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String id) async {
    try {
      await api.dio.put('/api/Residents/$id/approve');
      if (!mounted) return;
      showSnack(context, 'Đã duyệt yêu cầu liên kết căn hộ');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi duyệt: $e', error: true);
    }
  }

  Future<void> _reject(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận từ chối'),
        content: const Text('Bạn có chắc muốn từ chối yêu cầu liên kết căn hộ này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Từ chối'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await api.dio.put('/api/Residents/$id/reject');
        if (!mounted) return;
        showSnack(context, 'Đã từ chối yêu cầu');
        await _load();
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Lỗi từ chối: $e', error: true);
      }
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Gradient Cong
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 50), // 50 bottom để chừa chỗ cho search
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duyệt → Căn hộ', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('Đang chờ: ${_items.length} yêu cầu', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),

        // Floating Search Bar
        Positioned(
          bottom: -25,
          left: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Tìm theo CMND, SĐT, Mã căn hộ...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _search.clear();
                    _load();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: GoogleFonts.inter(),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(PendingResidentRequest req, BuildContext context) {
    final theme = Theme.of(context);
    final apartmentCode = req.apartment?.code ?? 'N/A';
    final apartmentDetails = req.apartment != null ? 'Tòa ${req.apartment!.building} • Tầng ${req.apartment!.floor}' : 'Chưa có căn hộ';

    return Card(
      elevation: 0, // Using flat style with shadow from container usually, but keeping Card for now
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Apartment Code & Details
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.home_work_outlined, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CĂN HỘ: $apartmentCode', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(apartmentDetails, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(DateFormat('dd/MM').format(req.createdAtUtc.toLocal()), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const Divider(height: 24),

            // Body: User Info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow('Loại cư dân:', req.residentType ?? 'Chủ hộ', theme),
                      _InfoRow('SĐT:', req.phone ?? 'N/A', theme),
                      _InfoRow('Email:', req.email ?? 'N/A', theme),
                      if (req.nationalId != null) _InfoRow('CMND/CCCD:', req.nationalId!, theme),
                      if (req.numResidents != null) _InfoRow('Số người:', req.numResidents.toString(), theme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _reject(req.id),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: Text('Từ chối', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _approve(req.id),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text('Duyệt', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _InfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 13))),
          Expanded(child: Text(value, style: GoogleFonts.inter(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Liên kết căn hộ', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // 1. HEADER & Floating Search
        _buildHeader(),

        // 2. Danh sách
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : _items.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_off_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Không có yêu cầu nào', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _load,
            color: _primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 30, left: 16, right: 16, bottom: 80), // Bù padding cho Floating Search
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final req = _items[i];
                return _buildRequestCard(req, context);
              },
            ),
          ),
        )
      ]),
    );
  }
}