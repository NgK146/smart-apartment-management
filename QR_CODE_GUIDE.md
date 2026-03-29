# Hướng dẫn QR Code - Từ Generation đến Database

## 📋 Tổng quan

QR codes được sử dụng cho:
1. **Visitor Access** - Khách vào tòa nhà
2. **Event Check-in** - Check-in sự kiện
3. **Barrier Access** - Mở cổng/barrier
4. **Smart Locker** - Mở locker (dùng OTP hoặc QR)

## 🔧 Backend Implementation (C#)

### 1. Database Entity

Đã tạo `VisitorAccess.cs` trong `ICitizen.Domain`:

```csharp
public class VisitorAccess
{
    public Guid Id { get; set; }
    public Guid ResidentId { get; set; }
    public string ApartmentCode { get; set; }
    public string VisitorName { get; set; }
    public string? VisitorPhone { get; set; }
    public string? VisitorEmail { get; set; }
    public DateTime VisitDate { get; set; }
    public string? VisitTime { get; set; }
    public string? Purpose { get; set; }
    public string QrCode { get; set; } // Format: VISITOR_{timestamp}_{hash}
    public string? QrCodeUrl { get; set; }
    public string Status { get; set; } // pending, checkedIn, checkedOut, expired, cancelled
    public DateTime? CheckedInAt { get; set; }
    public DateTime? CheckedOutAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
}
```

### 2. Migration

Chạy migration để tạo bảng:

```bash
# Trong thư mục ICitizen/ICitizenAPI/ICitizen
dotnet ef migrations add AddVisitorAccess
dotnet ef database update
```

### 3. Controller

Đã tạo `VisitorController.cs` với các endpoints:

- `POST /api/Visitor/create` - Tạo visitor access và generate QR
- `GET /api/Visitor/my-visitors` - Lấy danh sách visitor của cư dân
- `POST /api/Visitor/validate-qr` - Validate QR code (public, không cần auth)
- `POST /api/Visitor/check-in` - Check-in visitor (chỉ Manager/Security)
- `POST /api/Visitor/{id}/check-out` - Check-out visitor
- `DELETE /api/Visitor/{id}` - Hủy visitor access

### 4. QR Code Generation Logic

QR code được generate trong `VisitorController.CreateVisitorAccess`:

```csharp
// Format: VISITOR_{timestamp}_{hash}
var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
var randomBytes = new byte[8];
using (var rng = RandomNumberGenerator.Create())
{
    rng.GetBytes(randomBytes);
}
var hash = Convert.ToBase64String(randomBytes)
    .Replace("+", "-")
    .Replace("/", "_")
    .Substring(0, 12);
var qrCode = $"VISITOR_{timestamp}_{hash}";
```

**Lưu vào database:**
```csharp
visitorAccess.QrCode = qrCode;
visitorAccess.QrCodeUrl = $"{Request.Scheme}://{Request.Host}/api/Visitor/validate-qr?code={qrCode}";
visitorAccess.ExpiresAt = visitDate.AddDays(1); // Hết hạn sau 1 ngày
_context.VisitorAccesses.Add(visitorAccess);
await _context.SaveChangesAsync();
```

## 📱 Flutter Implementation

### 1. API Service

Đã tạo `lib/core/services/visitor_service.dart`:

```dart
class VisitorService {
  final Dio _dio;

  VisitorService(this._dio);

  // Tạo visitor access và nhận QR code từ backend
  Future<VisitorAccess> createVisitorAccess({
    required String visitorName,
    String? visitorPhone,
    String? visitorEmail,
    required DateTime visitDate,
    String? visitTime,
    String? purpose,
  }) async {
    final response = await _dio.post(
      '/api/Visitor/create',
      data: {
        'visitorName': visitorName,
        'visitorPhone': visitorPhone,
        'visitorEmail': visitorEmail,
        'visitDate': visitDate.toIso8601String(),
        'visitTime': visitTime,
        'purpose': purpose,
      },
    );
    return VisitorAccess.fromJson(response.data);
  }

  // Validate QR code khi scan
  Future<VisitorAccess?> validateQRCode(String qrCode) async {
    try {
      final response = await _dio.post(
        '/api/Visitor/validate-qr',
        data: {'qrCode': qrCode},
      );
      return VisitorAccess.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // QR code không hợp lệ
      }
      rethrow;
    }
  }
}
```

### 2. Sử dụng trong UI

**Tạo Visitor Access và hiển thị QR:**

```dart
// Trong visitor_access_page.dart
final visitorService = VisitorService(api.dio);

Future<void> _createQR() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => _isSubmitting = true);
  
  try {
    // Gọi API để tạo visitor access và nhận QR code
    final visitorAccess = await visitorService.createVisitorAccess(
      visitorName: _nameController.text,
      visitorPhone: _phoneController.text,
      visitorEmail: _emailController.text,
      visitDate: _selectedDate!,
      visitTime: _selectedTime?.format(context),
      purpose: _purposeController.text,
    );
    
    // Hiển thị QR code
    showDialog(
      context: context,
      builder: (context) => _QRCodeDialog(
        qrCode: visitorAccess.qrCode, // QR code từ backend
        visitorName: visitorAccess.visitorName,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: ${e.toString()}')),
    );
  } finally {
    setState(() => _isSubmitting = false);
  }
}
```

**Hiển thị QR Code:**

```dart
// Sử dụng qr_flutter package
QrImageView(
  data: visitorAccess.qrCode, // QR code string từ backend
  size: 200,
  backgroundColor: Colors.white,
  foregroundColor: theme.colorScheme.primary,
)
```

### 3. Scan QR Code

Để scan QR code, bạn cần thêm package `qr_code_scanner`:

```yaml
# pubspec.yaml
dependencies:
  qr_code_scanner: ^1.0.1
```

**Tạo QR Scanner Page:**

```dart
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final visitorService = VisitorService(api.dio);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quét QR Code')),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null) {
        controller.pauseCamera();
        
        // Validate QR code với backend
        final visitorAccess = await visitorService.validateQRCode(scanData.code!);
        
        if (visitorAccess != null) {
          // Hiển thị thông tin visitor
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Thông tin khách'),
              content: Text('Tên: ${visitorAccess.visitorName}\n'
                  'Căn hộ: ${visitorAccess.apartmentCode}\n'
                  'Ngày: ${visitorAccess.visitDate}'),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Check-in visitor
                    await visitorService.checkInVisitor(scanData.code!);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('Check-in'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('QR code không hợp lệ hoặc đã hết hạn')),
          );
          controller.resumeCamera();
        }
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
```

## 🔄 Flow hoàn chỉnh

### 1. Cư dân tạo Visitor Access

```
User (Flutter) 
  → POST /api/Visitor/create
  → Backend generate QR code
  → Lưu vào database (VisitorAccess table)
  → Trả về QR code cho Flutter
  → Flutter hiển thị QR code bằng QrImageView
```

### 2. Khách scan QR tại cổng

```
Security/Manager scan QR
  → POST /api/Visitor/validate-qr (public endpoint)
  → Backend kiểm tra QR code trong database
  → Kiểm tra expiresAt
  → Trả về thông tin visitor
  → Security check-in: POST /api/Visitor/check-in
  → Backend update status = "checkedIn"
  → Lưu CheckedInAt timestamp
```

### 3. Check-out

```
Security check-out
  → POST /api/Visitor/{id}/check-out
  → Backend update status = "checkedOut"
  → Lưu CheckedOutAt timestamp
```

## 🗄️ Database Schema

```sql
CREATE TABLE VisitorAccesses (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    ResidentId UNIQUEIDENTIFIER NOT NULL,
    ApartmentCode NVARCHAR(20) NOT NULL,
    VisitorName NVARCHAR(200) NOT NULL,
    VisitorPhone NVARCHAR(20),
    VisitorEmail NVARCHAR(200),
    VisitDate DATETIME2 NOT NULL,
    VisitTime NVARCHAR(10),
    Purpose NVARCHAR(500),
    QrCode NVARCHAR(100) NOT NULL UNIQUE, -- QR code string
    QrCodeUrl NVARCHAR(500),
    Status NVARCHAR(20) NOT NULL, -- pending, checkedIn, checkedOut, expired, cancelled
    CheckedInAt DATETIME2,
    CheckedOutAt DATETIME2,
    CreatedAt DATETIME2 NOT NULL,
    ExpiresAt DATETIME2 NOT NULL,
    FOREIGN KEY (ResidentId) REFERENCES ResidentProfiles(Id)
);

CREATE INDEX IX_VisitorAccesses_QrCode ON VisitorAccesses(QrCode);
CREATE INDEX IX_VisitorAccesses_ResidentId ON VisitorAccesses(ResidentId);
```

## 🔐 Security

1. **QR Code Format**: Sử dụng timestamp + random hash để tránh guess
2. **Expiration**: QR code tự động hết hạn sau 1 ngày
3. **Validation**: Mỗi QR code chỉ check-in được 1 lần
4. **Authorization**: Check-in chỉ dành cho Manager/Security role
5. **Public Endpoint**: `/validate-qr` là public để scan được mà không cần login

## 📝 Next Steps

1. ✅ Tạo migration cho VisitorAccess table
2. ✅ Test API endpoints
3. ✅ Tích hợp Flutter với API
4. ⏳ Thêm QR scanner cho Security app
5. ⏳ Thêm notification khi visitor check-in
6. ⏳ Thêm analytics cho visitor access

## 🐛 Troubleshooting

**QR code không scan được:**
- Kiểm tra format: phải bắt đầu với `VISITOR_`
- Kiểm tra expiresAt: QR code có thể đã hết hạn
- Kiểm tra status: QR code có thể đã được sử dụng

**Lỗi database:**
- Đảm bảo đã chạy migration
- Kiểm tra connection string
- Kiểm tra foreign key constraint với ResidentProfiles



