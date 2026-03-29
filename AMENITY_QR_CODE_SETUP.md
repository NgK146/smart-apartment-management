# Hướng dẫn cấu hình QR Code thanh toán cho Tiện ích

## ✅ Đã kiểm tra và đảm bảo

### 1. Backend Logic (C#)
- ✅ **Tạo Invoice**: Khi tiện ích có `pricePerHour > 0`, backend tự động tạo invoice
- ✅ **Tạo Payment**: Tự động tạo payment với method VNPay
- ✅ **Tạo QR Code**: Tự động tạo QR code từ VNPay payment URL
- ✅ **Validation**: Kiểm tra payment URL hợp lệ trước khi trả về
- ✅ **Error Handling**: Log chi tiết khi có lỗi (VNPay chưa cấu hình, URL không hợp lệ)

**File**: `ICitizen/ICitizenAPI/ICitizen/Controllers/AmenityBookingsController.cs`

### 2. Frontend - Admin Form (Flutter)
- ✅ **Form có trường giá**: Admin có thể nhập `pricePerHour` trong tab "Cài đặt"
- ✅ **Thông báo rõ ràng**: Đã thêm thông báo giải thích rằng nếu đặt giá sẽ tự động tạo QR code
- ✅ **Hiển thị giá**: Card tiện ích hiển thị giá nếu có

**File**: `lib/features/manager/amenities_admin_page.dart`

### 3. Frontend - User Booking (Flutter)
- ✅ **Hiển thị QR Code**: Tự động hiển thị dialog QR code khi có `qrData` và `amount > 0`
- ✅ **Xử lý không có QR**: Hiển thị cảnh báo và đề xuất thanh toán qua VNPay
- ✅ **Debug Logging**: Log chi tiết để debug:
  - Tiện ích miễn phí → "Tiện ích này miễn phí nên không cần QR code"
  - Có phí nhưng không có QR → "Có phí nhưng không có QR code. Có thể VNPay chưa được cấu hình"

**File**: `lib/features/amenities/amenity_booking_page.dart`

### 4. VNPay Configuration
- ✅ **Đã cấu hình**: VNPay settings trong `appsettings.json`
  - TmnCode: "VNGEPY22"
  - HashSecret: đã có
  - BaseUrl: sandbox VNPay
  - ReturnUrl & IpnUrl: đã cấu hình

**File**: `ICitizen/ICitizenAPI/ICitizen/appsettings.json`

## 📋 Cách sử dụng

### Bước 1: Admin đặt giá cho tiện ích
1. Vào **Quản lý tiện ích** (Manager Dashboard)
2. Chọn tiện ích cần chỉnh sửa hoặc tạo mới
3. Vào tab **"Cài đặt"**
4. Nhập **"Giá/giờ (đ)"** (ví dụ: 50000)
5. Lưu

### Bước 2: Cư dân đặt lịch
1. Cư dân chọn tiện ích có giá
2. Chọn thời gian
3. Nhấn **"Xác nhận đặt lịch"**
4. **QR code sẽ tự động hiển thị** nếu:
   - Tiện ích có giá (`pricePerHour > 0`)
   - VNPay đã được cấu hình đúng
   - Backend tạo payment URL thành công

## 🔍 Debug & Troubleshooting

### Kiểm tra Console Log
Khi đặt lịch, xem console log:
```
🔍 Booking response: invoiceId=..., amount=..., qrData=...
```

**Các trường hợp:**
- `amount=0, qrData=NULL` → Tiện ích miễn phí (đúng)
- `amount>0, qrData=NULL` → Có lỗi tạo QR code (kiểm tra VNPay config)
- `amount>0, qrData=HAS_DATA` → ✅ QR code đã được tạo thành công

### Kiểm tra Backend Logs
Nếu không có QR code mặc dù có giá, kiểm tra backend logs:
- `Payment URL từ VNPay là null hoặc empty` → VNPay chưa cấu hình đúng
- `Payment URL từ VNPay không hợp lệ` → URL format sai
- `Đã tạo QR code thành công` → ✅ QR code đã được tạo

### Kiểm tra VNPay Settings
Trong `appsettings.json`, đảm bảo:
```json
{
  "VnPay": {
    "TmnCode": "...",
    "HashSecret": "...",
    "BaseUrl": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
    "ReturnUrl": "...",
    "IpnUrl": "..."
  }
}
```

## ⚠️ Lưu ý

1. **Tiện ích miễn phí**: Nếu `pricePerHour = null` hoặc `0`, sẽ không tạo invoice và không có QR code (đúng logic)

2. **VNPay Sandbox**: Hiện đang dùng sandbox VNPay. Khi deploy production, cần:
   - Đổi `BaseUrl` sang production URL
   - Cập nhật `TmnCode` và `HashSecret` từ VNPay production

3. **QR Code Format**: QR code chứa payment URL từ VNPay, có thể quét bằng app ngân hàng

## ✅ Kết luận

Hệ thống đã được cấu hình đầy đủ để:
- ✅ Admin có thể đặt giá cho tiện ích
- ✅ Backend tự động tạo invoice và payment khi có giá
- ✅ Backend tự động tạo QR code từ VNPay
- ✅ Frontend hiển thị QR code cho người dùng
- ✅ Có xử lý lỗi và thông báo rõ ràng

**Để test**: Tạo một tiện ích mới với giá (ví dụ: 50000 đ/giờ), sau đó đặt lịch để xem QR code hiển thị.






















