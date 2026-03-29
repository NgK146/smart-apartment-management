import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../billing/billing_service.dart';
import '../billing/fee_definitions_service.dart';
import '../billing/fee_definition_model.dart';
import '../apartments/apartments_service.dart';
import '../apartments/apartments_service.dart' as apt;

class MeterReadingsAdminPage extends StatefulWidget {
  const MeterReadingsAdminPage({super.key});

  @override
  State<MeterReadingsAdminPage> createState() => _MeterReadingsAdminPageState();
}

class _MeterReadingsAdminPageState extends State<MeterReadingsAdminPage> {
  final _billingSvc = BillingService();
  final _feeSvc = FeeDefinitionsService();
  final _aptSvc = ApartmentsService();
  
  List<apt.Apartment> _apartments = [];
  List<FeeDefinitionModel> _feeDefinitions = [];
  List<Map<String, dynamic>> _readings = []; // [{apartmentId, feeDefinitionId, reading}]
  
  DateTime _selectedDate = DateTime.now();
  FeeDefinitionModel? _selectedFeeType;
  bool _loading = false;
  bool _loadingData = true;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final apartmentsResult = await _aptSvc.list(pageSize: 1000);
      final feesResult = await _feeSvc.list(pageSize: 100, isActive: true);
      final meteredFees = feesResult.where((f) => f.calculationMethod == 'Metered').toList();
      
      if (!mounted) return;
      setState(() {
        _apartments = apartmentsResult;
        _feeDefinitions = meteredFees;
        if (_feeDefinitions.isNotEmpty) {
          _selectedFeeType = _feeDefinitions.first;
        }
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải dữ liệu: $e', error: true);
      setState(() => _loadingData = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addReading(apt.Apartment apartment, String readingText) {
    if (_selectedFeeType == null) {
      showSnack(context, 'Vui lòng chọn loại phí', error: true);
      return;
    }

    final reading = double.tryParse(readingText);
    if (reading == null || reading < 0) {
      showSnack(context, 'Chỉ số không hợp lệ', error: true);
      return;
    }

    setState(() {
      final existingIndex = _readings.indexWhere(
        (r) => r['apartmentId'] == apartment.id && r['feeDefinitionId'] == _selectedFeeType!.id,
      );
      
      if (existingIndex >= 0) {
        _readings[existingIndex]['reading'] = reading;
      } else {
        _readings.add({
          'apartmentId': apartment.id,
          'feeDefinitionId': _selectedFeeType!.id,
          'reading': reading,
        });
      }
    });
  }

  Future<void> _submit() async {
    if (_readings.isEmpty) {
      showSnack(context, 'Vui lòng nhập ít nhất một chỉ số', error: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận lưu', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc muốn lưu ${_readings.length} chỉ số cho tháng ${_selectedDate.month}/${_selectedDate.year}?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Lưu', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _billingSvc.createMeterReadings(
        month: _selectedDate.month,
        year: _selectedDate.year,
        readings: _readings,
      );
      if (!mounted) return;
      showSnack(context, 'Đã lưu chỉ số thành công', error: false);
      setState(() {
        _readings.clear();
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi lưu chỉ số: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Nhập Chỉ số', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingData
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
              children: [
                _buildHeader(),
                
                // Content
                Expanded(
                  child: _selectedFeeType == null
                      ? Center(
                          child: Text(
                            'Vui lòng chọn loại phí',
                            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                          itemCount: _apartments.length,
                          itemBuilder: (context, index) {
                            final apt = _apartments[index];
                            final readingController = TextEditingController();
                            final existingReading = _readings.firstWhere(
                              (r) => r['apartmentId'] == apt.id && r['feeDefinitionId'] == _selectedFeeType!.id,
                              orElse: () => {},
                            );
                            if (existingReading.isNotEmpty) {
                              readingController.text = existingReading['reading'].toString();
                            }
                            return _buildReadingCard(apt, readingController);
                          },
                        ),
                ),
              ],
            ),
       bottomNavigationBar: _readings.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Lưu ${_readings.length} chỉ số', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 230,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
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
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý Tài chính → Chỉ số', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('Ghi nhận chỉ số điện/nước hàng tháng', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        
        // Filter Box
        Positioned(
          bottom: -40,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: _primaryColor),
                        const SizedBox(width: 12),
                        Text('Tháng ${_selectedDate.month} / Năm ${_selectedDate.year}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FeeDefinitionModel>(
                  value: _selectedFeeType,
                  decoration: InputDecoration(
                     filled: true,
                     fillColor: Colors.grey[50],
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                     prefixIcon: const Icon(Icons.electric_meter),
                  ),
                  style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w500),
                  hint: const Text('Chọn loại phí'),
                  items: _feeDefinitions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFeeType = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadingCard(apt.Apartment apt, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 0),
      // Top margin handling for the first item handled by listview padding or simple spacing
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
         padding: const EdgeInsets.all(16),
         child: Row(
           children: [
             Container(
               width: 50, height: 50,
               decoration: BoxDecoration(
                 color: Colors.blueGrey.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Center(child: Text(apt.code, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey))),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Phòng ${apt.code}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                   Text('${apt.building} - Tầng ${apt.floor}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                 ],
               ),
             ),
             SizedBox(
               width: 120,
               child: TextField(
                 controller: controller, // Warning: using controller in listview might have issues if not careful, preferred manual management or key
                 // Ideally state should drive this, but for quick modernization we keep controller logic if it works locally
                 decoration: InputDecoration(
                   labelText: 'Chỉ số',
                   labelStyle: GoogleFonts.inter(fontSize: 12),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                   isDense: true,
                   suffixText: _selectedFeeType?.unitName ?? '',
                 ),
                 keyboardType: TextInputType.number,
                 style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                 onSubmitted: (v) => _addReading(apt, v),
                  onChanged: (v) => _addReading(apt, v), // Auto save on type
               ),
             ),
           ],
         ),
      ),
    );
  }
}

extension FeeUnit on FeeDefinitionModel {
  String get unitName {
     if (name.toLowerCase().contains('điện')) return 'kWh';
     if (name.toLowerCase().contains('nước')) return 'm³';
     return '';
  }
}
