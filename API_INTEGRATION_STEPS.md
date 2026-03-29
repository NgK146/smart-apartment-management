# Hướng dẫn tích hợp API thật - Step by Step

## ✅ Đã hoàn thành

1. ✅ Tạo Flutter API Services
2. ✅ Tạo Backend C# Controller (VisitorController)
3. ✅ Tạo Database Entity (VisitorAccess)
4. ✅ Cập nhật ApplicationDbContext
5. ✅ Tạo QR Code Helper

## 📋 Các bước tiếp theo

### Bước 1: Tạo Migration cho VisitorAccess

```bash
# Trong thư mục ICitizen/ICitizenAPI/ICitizen
dotnet ef migrations add AddVisitorAccess
dotnet ef database update
```

### Bước 2: Cập nhật Flutter Pages để dùng API thật

**Trong `lib/features/visitor/visitor_access_page.dart`:**

```dart
import '../../core/api_client.dart';
import '../../core/services/visitor_service.dart';

class _CreateVisitorFormState extends State<_CreateVisitorForm> {
  final visitorService = VisitorService(api.dio); // Thêm service
  
  Future<void> _createQR() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày và giờ')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Gọi API thật thay vì mock data
      final visitorAccess = await visitorService.createVisitorAccess(
        visitorName: _nameController.text,
        visitorPhone: _phoneController.text.isEmpty ? null : _phoneController.text,
        visitorEmail: _emailController.text.isEmpty ? null : _emailController.text,
        visitDate: _selectedDate!,
        visitTime: _selectedTime?.format(context),
        purpose: _purposeController.text.isEmpty ? null : _purposeController.text,
      );

      if (!mounted) return;

      // Hiển thị QR code từ API
      showDialog(
        context: context,
        builder: (context) => _QRCodeDialog(
          qrCode: visitorAccess.qrCode, // QR code từ backend
          visitorName: visitorAccess.visitorName,
        ),
      );

      // Reset form
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _purposeController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
```

**Cập nhật History Tab:**

```dart
class _VisitorAccessPageState extends State<VisitorAccessPage> {
  final visitorService = VisitorService(api.dio);
  List<VisitorAccess> _visitors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      _visitors = await visitorService.getMyVisitors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải danh sách: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          return _VisitorCard(
            visitor: _visitors[index],
            onRefresh: _loadVisitors,
          );
        },
      ),
    );
  }
}
```

### Bước 3: Thêm QR Scanner (Optional)

Để scan QR code, thêm package:

```yaml
# pubspec.yaml
dependencies:
  qr_code_scanner: ^1.0.1
```

Tạo QR Scanner page (xem `QR_CODE_GUIDE.md`)

### Bước 4: Test API

1. **Start Backend:**
   ```bash
   cd ICitizen/ICitizenAPI/ICitizen
   dotnet run
   ```

2. **Test với Postman/Thunder Client:**
   - POST `http://localhost:5000/api/Visitor/create`
   - Headers: `Authorization: Bearer {token}`
   - Body:
     ```json
     {
       "visitorName": "Nguyễn Văn A",
       "visitorPhone": "0901234567",
       "visitDate": "2024-11-20T14:00:00Z",
       "visitTime": "14:00",
       "purpose": "Thăm bạn"
     }
     ```

3. **Test Validate QR:**
   - POST `http://localhost:5000/api/Visitor/validate-qr`
   - Body:
     ```json
     {
       "qrCode": "VISITOR_1234567890_abc123"
     }
     ```

### Bước 5: Tạo các Controllers khác

Tương tự VisitorController, tạo:

1. **ConciergeController.cs** - Quản lý dịch vụ concierge
2. **PaymentController.cs** - Quản lý ví điện tử
3. **EventsController.cs** - Quản lý sự kiện
4. **SmartDevicesController.cs** - Quản lý thiết bị thông minh

Xem `INTEGRATION_GUIDE.md` để biết chi tiết.

## 🔍 Kiểm tra lỗi

### Lỗi thường gặp:

1. **"VisitorAccess not found in ApplicationDbContext"**
   - ✅ Đã thêm `DbSet<VisitorAccess>` vào ApplicationDbContext
   - Chạy lại migration

2. **"QR code không hợp lệ"**
   - Kiểm tra format: phải bắt đầu với `VISITOR_`
   - Kiểm tra expiresAt trong database
   - Kiểm tra status (có thể đã được sử dụng)

3. **"401 Unauthorized"**
   - Kiểm tra token trong header
   - Token có thể đã hết hạn

4. **"Foreign key constraint"**
   - Đảm bảo ResidentId tồn tại trong ResidentProfiles
   - Kiểm tra user đã link apartment chưa

## 📝 Checklist

- [ ] Chạy migration `AddVisitorAccess`
- [ ] Test API với Postman
- [ ] Cập nhật Flutter pages để dùng API thật
- [ ] Test tạo visitor access từ Flutter
- [ ] Test validate QR code
- [ ] Test check-in visitor
- [ ] Thêm error handling
- [ ] Thêm loading states
- [ ] Test trên thiết bị thật

## 🎯 Next Steps

1. Tạo các controllers còn lại (Concierge, Payment, Events, SmartDevices)
2. Tạo database entities tương ứng
3. Tạo migrations
4. Tích hợp vào Flutter
5. Test end-to-end



