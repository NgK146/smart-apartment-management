import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ui/snackbar.dart';
import '../billing/fee_definitions_service.dart';
import '../billing/fee_definition_model.dart';

class FeeTypesAdminPage extends StatefulWidget {
  const FeeTypesAdminPage({super.key});

  @override
  State<FeeTypesAdminPage> createState() => _FeeTypesAdminPageState();
}

class _FeeTypesAdminPageState extends State<FeeTypesAdminPage> {
  final _svc = FeeDefinitionsService();
  final _searchController = TextEditingController();
  List<FeeDefinitionModel> _items = [];
  bool _loading = true;

  final Color _primaryColor = const Color(0xFF009688);
  final Color _secondaryColor = const Color(0xFF00796B);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final query = _searchController.text.trim();
      final items = await _svc.list(
        search: query.isEmpty ? null : query,
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Lỗi tải danh sách: $e', error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([FeeDefinitionModel? item]) async {
    final result = await showModalBottomSheet<FeeDefinitionModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeeDefinitionForm(item: item),
    );

    if (result != null) {
      try {
        if (item == null) {
          await _svc.create(result);
          if (!mounted) return;
          showSnack(context, 'Đã thêm loại phí', error: false);
        } else {
          await _svc.update(result.id, result);
          if (!mounted) return;
          showSnack(context, 'Đã cập nhật loại phí', error: false);
        }
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Lỗi: $e', error: true);
      }
      await _load();
    }
  }

  Future<void> _delete(FeeDefinitionModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa "${item.name}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Xóa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _svc.delete(item.id);
        if (!mounted) return;
        showSnack(context, 'Đã xóa loại phí', error: false);
        await _load();
      } catch (e) {
        if (!mounted) return;
        showSnack(context, 'Lỗi xóa: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Danh mục Phí', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Thêm loại phí', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryColor,
      ),
      body: Column(
        children: [
          _buildHeader(),
          
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                   color: _primaryColor,
                   onRefresh: _load,
              child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _buildFeeCard(_items[index]);
              },
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
          height: 180,
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
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Quản lý Tài chính → Phí', 
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text('Định nghĩa các loại phí trong hệ thống', 
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -28,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm loại phí...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Chưa có loại phí nào',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeCard(FeeDefinitionModel item) {
    final currencyFormatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedAmount = item.amount.toStringAsFixed(0).replaceAllMapped(currencyFormatter, (Match m) => '${m[1]},');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () { /* Show details or edit */ },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.monetization_on_outlined, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!item.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Vô hiệu', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$formattedAmount đ',
                            style: GoogleFonts.inter(color: _primaryColor, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 20), const SizedBox(width: 8), Text('Chỉnh sửa', style: GoogleFonts.inter())])),
                        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.red, size: 20), const SizedBox(width: 8), Text('Xóa', style: GoogleFonts.inter(color: Colors.red))])),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _createOrEdit(item);
                        } else if (value == 'delete') {
                          _delete(item);
                        }
                      },
                    ),
                  ],
                ),
                
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    item.description!,
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                     _buildChip(item.calculationMethodText, Icons.calculate_outlined),
                     _buildChip(item.periodTypeText, Icons.calendar_today_outlined),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _FeeDefinitionForm extends StatefulWidget {
  final FeeDefinitionModel? item;
  const _FeeDefinitionForm({this.item});

  @override
  State<_FeeDefinitionForm> createState() => _FeeDefinitionFormState();
}

class _FeeDefinitionFormState extends State<_FeeDefinitionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _calculationMethod = 'Fixed';
  String _periodType = 'Monthly';
  bool _isActive = true;
  final Color _primaryColor = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description ?? '';
      _amountController.text = widget.item!.amount.toStringAsFixed(0);
      _calculationMethod = widget.item!.calculationMethod;
      _periodType = widget.item!.periodType;
      _isActive = widget.item!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                 child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item == null ? 'Thêm loại phí' : 'Cập nhật loại phí',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildTextField(_nameController, 'Tên loại phí *', Icons.label_outline),
              const SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Mô tả', Icons.description_outlined, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(_amountController, 'Số tiền (VNĐ) *', Icons.attach_money, isNumber: true, helperText: 'VD: 100000 (cố định), 5000 (theo m²)'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _calculationMethod,
                      decoration: _inputDecoration('Phương thức tính *', Icons.calculate_outlined),
                      items: [
                         _buildDropdownItem('Fixed', 'Cố định'),
                         _buildDropdownItem('PerM2', 'Theo m²'),
                         _buildDropdownItem('PerUnit', 'Theo đơn vị'),
                         _buildDropdownItem('Metered', 'Theo chỉ số'),
                      ],
                      onChanged: (v) => setState(() => _calculationMethod = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _periodType,
                      decoration: _inputDecoration('Chu kỳ *', Icons.calendar_today_outlined),
                      items: [
                        _buildDropdownItem('Monthly', 'Hàng tháng'),
                        _buildDropdownItem('Quarterly', 'Hàng quý'),
                        _buildDropdownItem('Yearly', 'Hàng năm'),
                      ],
                      onChanged: (v) => setState(() => _periodType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: Text('Đang kích hoạt', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Loại phí này sẽ được áp dụng khi tạo hóa đơn', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                value: _isActive,
                activeColor: _primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isActive = v),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final model = FeeDefinitionModel(
                        id: widget.item?.id ?? '',
                        name: _nameController.text.trim(),
                        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                        amount: double.parse(_amountController.text),
                        calculationMethod: _calculationMethod,
                        periodType: _periodType,
                        isActive: _isActive,
                        createdAtUtc: widget.item?.createdAtUtc ?? DateTime.now(),
                      );
                      Navigator.pop(context, model);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(widget.item == null ? 'Thêm mới' : 'Lưu thay đổi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? helperText}) {
     return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[600]),
        helperText: helperText,
        helperStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1, String? helperText}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon, helperText: helperText),
      style: GoogleFonts.inter(),
      validator: (v) {
         if (label.contains('*') && (v == null || v.isEmpty)) return 'Vui lòng nhập thông tin này';
         if (isNumber && v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Phải là số hợp lệ';
         return null;
      },
    );
  }
  
  DropdownMenuItem<String> _buildDropdownItem(String value, String text) {
    return DropdownMenuItem(
      value: value,
      child: Text(text, style: GoogleFonts.inter(fontSize: 14)),
    );
  }
}
