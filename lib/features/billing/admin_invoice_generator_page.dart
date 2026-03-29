import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

class Apartment {
  final String id;
  final String code;
  final String building;
  final int floor;
  final double? areaM2;
  final String? status;

  Apartment({
    required this.id,
    required this.code,
    required this.building,
    required this.floor,
    this.areaM2,
    this.status,
  });

  factory Apartment.fromJson(Map<String, dynamic> j) {
    String? statusStr;
    final statusValue = j['status'];
    if (statusValue == null) {
      statusStr = null;
    } else if (statusValue is String) {
      statusStr = statusValue;
    } else if (statusValue is int) {
      switch (statusValue) {
        case 0: statusStr = 'Available'; break;
        case 1: statusStr = 'Occupied'; break;
        case 2: statusStr = 'Maintenance'; break;
        case 3: statusStr = 'Reserved'; break;
        default: statusStr = null;
      }
    } else {
      statusStr = statusValue.toString();
    }

    return Apartment(
      id: j['id'].toString(),
      code: j['code'].toString(),
      building: j['building'].toString(),
      floor: j['floor'] as int? ?? 0,
      areaM2: (j['areaM2'] as num?)?.toDouble(),
      status: statusStr,
    );
  }
}

class ApartmentsResponse {
  final List<Apartment> items;
  final int total;

  ApartmentsResponse({required this.items, required this.total});

  factory ApartmentsResponse.fromJson(Map<String, dynamic> j) {
    return ApartmentsResponse(
      items: (j['items'] as List)
          .map((e) => Apartment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: j['total'] as int? ?? 0,
    );
  }
}

class AdminInvoiceGeneratorPage extends StatefulWidget {
  const AdminInvoiceGeneratorPage({super.key});

  @override
  State<AdminInvoiceGeneratorPage> createState() => _AdminInvoiceGeneratorPageState();
}

class _AdminInvoiceGeneratorPageState extends State<AdminInvoiceGeneratorPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form fields
  String? _selectedApartmentId;
  Apartment? _selectedApartment;
  List<Apartment> _apartments = [];
  bool _loadingApartments = true;

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  DateTime? _dueDate;

  // Electricity
  final _elecOldController = TextEditingController(text: '0');
  final _elecNewController = TextEditingController(text: '0');
  final _elecPriceController = TextEditingController(text: '2200');
  double _elecUsage = 0;
  double _elecAmount = 0;

  // Water
  final _waterOldController = TextEditingController(text: '0');
  final _waterNewController = TextEditingController(text: '0');
  final _waterPriceController = TextEditingController(text: '15000');
  double _waterUsage = 0;
  double _waterAmount = 0;

  // Management
  final _mgmtFeeController = TextEditingController(text: '150000');
  double _mgmtAmount = 150000;

  double get _totalAmount => _elecAmount + _waterAmount + _mgmtAmount;

  bool _creating = false;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _loadApartments();
    _setDefaultDueDate();

    // Add listeners
    _elecOldController.addListener(_calculateElec);
    _elecNewController.addListener(_calculateElec);
    _elecPriceController.addListener(_calculateElec);
    _waterOldController.addListener(_calculateWater);
    _waterNewController.addListener(_calculateWater);
    _waterPriceController.addListener(_calculateWater);
    _mgmtFeeController.addListener(_calculateMgmt);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _elecOldController.dispose();
    _elecNewController.dispose();
    _elecPriceController.dispose();
    _waterOldController.dispose();
    _waterNewController.dispose();
    _waterPriceController.dispose();
    _mgmtFeeController.dispose();
    super.dispose();
  }

  void _setDefaultDueDate() {
    final nextMonth = DateTime(_year, _month + 1, 20);
    setState(() => _dueDate = nextMonth);
  }

  Future<void> _loadApartments() async {
    try {
      final response = await api.dio.get('/api/Apartments');
      final apartmentsResponse = ApartmentsResponse.fromJson(response.data);
      setState(() {
        _apartments = apartmentsResponse.items;
        _loadingApartments = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingApartments = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được danh sách căn hộ: $e')),
        );
      }
    }
  }

  void _calculateElec() {
    final oldVal = double.tryParse(_elecOldController.text) ?? 0;
    final newVal = double.tryParse(_elecNewController.text) ?? 0;
    final price = double.tryParse(_elecPriceController.text) ?? 0;

    setState(() {
      _elecUsage = (newVal - oldVal).clamp(0, double.infinity);
      _elecAmount = _elecUsage * price;
    });
  }

  void _calculateWater() {
    final oldVal = double.tryParse(_waterOldController.text) ?? 0;
    final newVal = double.tryParse(_waterNewController.text) ?? 0;
    final price = double.tryParse(_waterPriceController.text) ?? 0;

    setState(() {
      _waterUsage = (newVal - oldVal).clamp(0, double.infinity);
      _waterAmount = _waterUsage * price;
    });
  }

  void _calculateMgmt() {
    setState(() {
      _mgmtAmount = double.tryParse(_mgmtFeeController.text) ?? 0;
    });
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedApartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn căn hộ')));
      return;
    }

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hạn thanh toán')),
      );
      return;
    }

    final lines = <Map<String, dynamic>>[];

    // Add electricity
    if (_elecAmount > 0) {
      lines.add({
        'feeName': 'Tiền điện',
        'description': 'Điện tháng $_month/$_year (${_elecUsage.toStringAsFixed(0)} kWh × ${_formatCurrency(_elecPriceController.text)}/kWh)',
        'amount': _elecAmount,
        'quantity': _elecUsage,
        'unitPrice': double.tryParse(_elecPriceController.text) ?? 0,
      });
    }

    // Add water
    if (_waterAmount > 0) {
      lines.add({
        'feeName': 'Tiền nước',
        'description': 'Nước tháng $_month/$_year (${_waterUsage.toStringAsFixed(0)} m³ × ${_formatCurrency(_waterPriceController.text)}/m³)',
        'amount': _waterAmount,
        'quantity': _waterUsage,
        'unitPrice': double.tryParse(_waterPriceController.text) ?? 0,
      });
    }

    // Add management
    if (_mgmtAmount > 0) {
      lines.add({
        'feeName': 'Phí quản lý',
        'description': 'Phí quản lý chung cư tháng $_month/$_year',
        'amount': _mgmtAmount,
        'quantity': 1,
        'unitPrice': _mgmtAmount,
      });
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có khoản phí nào')));
      return;
    }

    setState(() => _creating = true);

    try {
      final invoiceData = {
        'apartmentId': _selectedApartmentId,
        'type': 'Monthly',
        'month': _month,
        'year': _year,
        'dueDate': _dueDate!.toIso8601String(),
        'lines': lines,
      };

      await api.dio.post('/api/Invoices', data: invoiceData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tạo hóa đơn thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Tạo hóa đơn thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _formatCurrency(String value) {
    final num = double.tryParse(value) ?? 0;
    return NumberFormat.currency(locale: 'vi_VN', symbol: '').format(num);
  }

  String _formatMoney(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPeriodCard(),
                      const SizedBox(height: 16),
                      _buildApartmentCard(),
                      const SizedBox(height: 16),
                      _buildElectricityCard(),
                      const SizedBox(height: 16),
                      _buildWaterCard(),
                      const SizedBox(height: 16),
                      _buildManagementCard(),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 24),
                      _buildCreateButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text('Quản lý hóa đơn', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('Tạo Hóa Đơn Tiện Ích', style: GoogleFonts.inter(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                   Text('Điện - Nước - Phí quản lý', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildPeriodCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_today, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Kỳ Hóa Đơn', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _month,
                  decoration: InputDecoration(
                    labelText: 'Tháng',
                    labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: List.generate(12, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text('Tháng $m', style: GoogleFonts.inter())))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _month = v!;
                    _setDefaultDueDate();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _year.toString(),
                  decoration: InputDecoration(
                    labelText: 'Năm',
                    labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.inter(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    final year = int.tryParse(v);
                    if (year != null) {
                      setState(() {
                        _year = year;
                        _setDefaultDueDate();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: _primaryColor),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Hạn thanh toán',
                labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: const Icon(Icons.calendar_month, color: Colors.grey),
              ),
              child: Text(
                _dueDate != null ? DateFormat('dd/MM/yyyy').format(_dueDate!) : 'Chọn ngày',
                style: GoogleFonts.inter(color: _dueDate != null ? Colors.black87 : Colors.grey[500]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Chọn Căn Hộ', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          if (_loadingApartments)
            Center(child: CircularProgressIndicator(color: _primaryColor))
          else
            DropdownButtonFormField<String>(
              value: _selectedApartmentId,
              decoration: InputDecoration(
                labelText: 'Căn hộ',
                labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: Icon(Icons.apartment, color: Colors.grey[500]),
              ),
              items: _apartments
                  .map((apt) => DropdownMenuItem(
                value: apt.id,
                child: Text('${apt.code} - Tòa ${apt.building} - Tầng ${apt.floor}', style: GoogleFonts.inter()),
              ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedApartmentId = v;
                  _selectedApartment = _apartments.firstWhere((a) => a.id == v);
                });
              },
            ),
          if (_selectedApartment != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedApartment!.code} | Tòa ${_selectedApartment!.building} | Tầng ${_selectedApartment!.floor} | ${_selectedApartment!.areaM2}m²',
                      style: GoogleFonts.inter(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildElectricityCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Tiền Điện', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTextField(_elecOldController, 'Chỉ số cũ (kWh)')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_elecNewController, 'Chỉ số mới (kWh)')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_elecPriceController, 'Đơn giá (₫/kWh)')),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sử dụng', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700])),
                      Text('${_elecUsage.toStringAsFixed(0)} kWh',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thành tiền:', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(_formatMoney(_elecAmount), style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Tiền Nước', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTextField(_waterOldController, 'Chỉ số cũ (m³)')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_waterNewController, 'Chỉ số mới (m³)')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_waterPriceController, 'Đơn giá (₫/m³)')),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sử dụng', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700])),
                      Text('${_waterUsage.toStringAsFixed(0)} m³',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thành tiền:', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(_formatMoney(_waterAmount), style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_center, color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Phí Quản Lý', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(_mgmtFeeController, 'Số tiền (₫)', prefixIcon: Icons.attach_money),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text('Tổng Hợp', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow('Tiền điện:', _elecAmount),
          const Divider(color: Colors.white24, height: 20),
          _buildSummaryRow('Tiền nước:', _waterAmount),
          const Divider(color: Colors.white24, height: 20),
          _buildSummaryRow('Phí quản lý:', _mgmtAmount),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TỔNG CỘNG', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_formatMoney(_totalAmount), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
        Text(_formatMoney(amount), style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _creating ? null : _createInvoice,
        style: FilledButton.styleFrom(
          backgroundColor: _secondaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: _secondaryColor.withOpacity(0.4),
        ),
        child: _creating
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Tạo Hóa Đơn', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {IconData? prefixIcon}) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[400]) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
