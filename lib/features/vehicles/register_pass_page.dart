import 'package:flutter/material.dart';
import '../../core/ui/snackbar.dart';
import '../billing/invoices_page.dart';
import 'vehicles_service.dart';
import 'vehicle_model.dart';
import 'parking_plan_model.dart';

class RegisterPassPage extends StatefulWidget {
  final VehicleModel vehicle;

  const RegisterPassPage({super.key, required this.vehicle});

  @override
  State<RegisterPassPage> createState() => _RegisterPassPageState();
}

class _RegisterPassPageState extends State<RegisterPassPage> {
  final _svc = VehiclesService();
  List<ParkingPlanModel> _plans = [];
  ParkingPlanModel? _selectedPlan;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final plans = await _svc.listPlans(vehicleType: widget.vehicle.vehicleType, isActive: true);
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (mounted) showSnack(context, 'Lỗi tải gói vé: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerPass() async {
    if (_selectedPlan == null) {
      showSnack(context, 'Vui lòng chọn gói vé', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _svc.registerPass(
        vehicleId: widget.vehicle.id,
        parkingPlanId: _selectedPlan!.id,
        validFrom: _selectedDate,
      );

      if (mounted) {
        // Chuyển đến trang thanh toán
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const InvoicesPage(),
          ),
        );
        showSnack(context, 'Đã tạo vé thành công. Vui lòng thanh toán hóa đơn.');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Lỗi đăng ký vé: $e', error: true);
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký mua vé'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Chưa có gói vé phù hợp', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Vui lòng liên hệ Ban quản lý', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thông tin xe
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.directions_car, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Xe đăng ký', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.vehicle.licensePlate,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text('${widget.vehicle.vehicleType}${widget.vehicle.color != null ? ' • ${widget.vehicle.color}' : ''}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Chọn gói vé
                      Text('Chọn gói vé', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._plans.map((plan) => _buildPlanCard(plan)),
                      const SizedBox(height: 24),
                      // Chọn ngày bắt đầu
                      Text('Ngày bắt đầu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedPlan != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: theme.colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tóm tắt', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Gói vé', _selectedPlan!.name),
                                _buildSummaryRow('Giá', _selectedPlan!.formattedPrice),
                                _buildSummaryRow('Thời hạn', _selectedPlan!.durationText),
                                _buildSummaryRow('Ngày bắt đầu', '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                                _buildSummaryRow(
                                  'Ngày hết hạn',
                                  '${_selectedDate.add(Duration(days: _selectedPlan!.durationInDays)).day}/${_selectedDate.add(Duration(days: _selectedPlan!.durationInDays)).month}/${_selectedDate.add(Duration(days: _selectedPlan!.durationInDays)).year}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _submitting ? null : _registerPass,
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Đăng ký và thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPlanCard(ParkingPlanModel plan) {
    final theme = Theme.of(context);
    final isSelected = _selectedPlan?.id == plan.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPlan = plan),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.confirmation_number,
                  color: isSelected ? theme.colorScheme.primary : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (plan.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.description!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(plan.durationText, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.formattedPrice,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Đã chọn',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

