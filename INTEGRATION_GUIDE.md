# Hướng dẫn tích hợp các tính năng 5 sao

## ✅ Đã hoàn thành

### 1. Theme UI/UX 5 sao
- ✅ Theme màu xanh đậm (#0A4A5C) + trắng + accent vàng (#F4A261)
- ✅ Font Inter đã được áp dụng
- ✅ Card style không elevation, border nhẹ, bo góc 20px

### 2. Các tính năng đã tạo

#### Concierge Page
- File: `lib/features/concierge/concierge_page.dart`
- Models: `lib/features/concierge/models/concierge_service.dart`
- Tính năng: Đặt dịch vụ dọn phòng, giặt ủi, sửa chữa, taxi, bảo vệ, lễ tân

#### Visitor Access Page
- File: `lib/features/visitor/visitor_access_page.dart`
- Models: `lib/features/visitor/models/visitor_access.dart`
- Tính năng: Tạo QR cho khách, quản lý lịch khách, chia sẻ QR

#### Digital Payment Page
- File: `lib/features/payment/digital_payment_page.dart`
- Models: `lib/features/payment/models/digital_payment.dart`
- Tính năng: Ví điện tử, QR bank, lịch sử giao dịch, nhắc nhở thanh toán

#### Community Events Page
- File: `lib/features/events/community_events_page.dart`
- Models: `lib/features/events/models/community_event.dart`
- Tính năng: Đăng ký sự kiện, check-in QR, quản lý sự kiện

#### Smart Devices Page
- File: `lib/features/smart_devices/smart_devices_page.dart`
- Models: `lib/features/smart_devices/models/smart_device.dart`
- Tính năng: Quản lý Barrier, Smart Locker, EV Charging Station

#### Enhanced Home Page
- File: `lib/features/shell/home_page_enhanced.dart`
- Tính năng: Dashboard tóm tắt, booking sắp tới, thông báo quan trọng, quick actions

#### Enhanced Manager Dashboard
- File: `lib/features/manager/manager_dashboard_enhanced.dart`
- Tính năng: Heatmap sử dụng, reports đẹp, trung tâm điều hành

## 📝 Cách tích hợp

### Bước 1: Thêm routes vào app

Trong `lib/main.dart` hoặc file routing của bạn, thêm các routes:

```dart
// Thêm vào MaterialApp routes hoặc Navigator
'/concierge': (context) => const ConciergePage(),
'/visitor': (context) => const VisitorAccessPage(),
'/payment': (context) => const DigitalPaymentPage(),
'/events': (context) => const CommunityEventsPage(),
'/smart-devices': (context) => const SmartDevicesPage(),
```

### Bước 2: Cập nhật Home Page

Thay thế `HomePage` hiện tại bằng `HomePageEnhanced`:

```dart
// Trong app_shell.dart hoặc nơi sử dụng HomePage
import 'package:icitizen_app/features/shell/home_page_enhanced.dart';

// Thay đổi:
case 0: page = HomePage(onNavigateToTab: _navigateToTab);
// Thành:
case 0: page = HomePageEnhanced(onNavigateToTab: _navigateToTab);
```

### Bước 3: Cập nhật Manager Dashboard

Thay thế `ManagerDashboard` bằng `ManagerDashboardEnhanced`:

```dart
// Trong manager_shell.dart
import 'package:icitizen_app/features/manager/manager_dashboard_enhanced.dart';

// Thay đổi:
case 0: page = const ManagerDashboard();
// Thành:
case 0: page = const ManagerDashboardEnhanced();
```

### Bước 4: Kết nối với Backend API

Các models đã được tạo sẵn với `fromJson` và `toJson`. Bạn cần:

1. Tạo API services tương ứng trong `lib/core/services/`:
   - `concierge_service.dart`
   - `visitor_service.dart`
   - `payment_service.dart`
   - `events_service.dart`
   - `smart_devices_service.dart`

2. Ví dụ service:

```dart
// lib/core/services/concierge_service.dart
class ConciergeService {
  final Dio _dio;
  
  ConciergeService(this._dio);
  
  Future<List<ConciergeService>> getServices() async {
    final response = await _dio.get('/api/Concierge/services');
    return (response.data as List)
        .map((json) => ConciergeService.fromJson(json))
        .toList();
  }
  
  Future<ConciergeRequest> createRequest(CreateRequestDto dto) async {
    final response = await _dio.post('/api/Concierge/requests', data: dto.toJson());
    return ConciergeRequest.fromJson(response.data);
  }
}
```

### Bước 5: Tạo Backend APIs (C#)

Bạn cần tạo các controllers tương ứng:

1. **ConciergeController.cs**
```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ConciergeController : ControllerBase
{
    [HttpGet("services")]
    public async Task<IActionResult> GetServices() { }
    
    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest([FromBody] CreateRequestDto dto) { }
}
```

2. **VisitorController.cs** - Quản lý visitor access và QR codes
3. **PaymentController.cs** - Quản lý ví điện tử và thanh toán
4. **EventsController.cs** - Quản lý sự kiện và đăng ký
5. **SmartDevicesController.cs** - Quản lý barrier, locker, EV charging

### Bước 6: Database Models (C#)

Tạo các entity models trong `ICitizen.Domain`:

- `ConciergeService`, `ConciergeRequest`
- `VisitorAccess`
- `DigitalWallet`, `WalletTransaction`, `PaymentMethod`
- `CommunityEvent`, `EventRegistration`
- `SmartBarrier`, `SmartLocker`, `EVChargingStation`

## ⚠️ Lưu ý

1. **QR Code**: Đã sử dụng package `qr_flutter`. Đảm bảo đã thêm vào `pubspec.yaml`:
   ```yaml
   qr_flutter: ^4.1.0
   ```

2. **Mock Data**: Hiện tại các pages đang dùng mock data. Cần thay thế bằng API calls thực tế.

3. **Navigation**: Các quick actions trong Home Page cần được kết nối với navigation thực tế.

4. **Permissions**: Một số tính năng có thể cần permissions (camera cho QR scanner, location, etc.)

## 🎨 Marketplace & Dịch vụ nội khu

Marketplace đã có sẵn trong codebase. Bạn có thể mở rộng thêm:
- Spa services
- Gym bookings
- F&B orders
- Resident discounts

## 📱 Next Steps

1. Tạo backend APIs cho tất cả các tính năng
2. Kết nối Flutter với APIs
3. Thêm error handling và loading states
4. Thêm animations và transitions
5. Test trên thiết bị thật
6. Tối ưu performance

## 🐛 Nếu gặp lỗi

- Kiểm tra imports đã đúng chưa
- Đảm bảo các packages đã được thêm vào `pubspec.yaml`
- Chạy `flutter pub get`
- Kiểm tra linter errors với `flutter analyze`



