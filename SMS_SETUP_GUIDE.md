# Hướng dẫn cấu hình SMS Service để gửi OTP thật

## Tổng quan

Hệ thống đã được tích hợp sẵn với các dịch vụ SMS phổ biến:
- **ESMS** (Việt Nam) - Khuyến nghị
- **BrandSMS** (Việt Nam)
- **Twilio** (Quốc tế)

## Bước 1: Chọn dịch vụ SMS

### Option 1: ESMS (Khuyến nghị cho Việt Nam)
- Website: https://esms.vn
- Giá: ~200-300 VNĐ/SMS
- Hỗ trợ tốt cho số điện thoại Việt Nam

**Cách đăng ký:**
1. Truy cập https://esms.vn
2. Đăng ký tài khoản
3. Nạp tiền vào tài khoản
4. Lấy API Key và API Secret từ trang quản trị

### Option 2: BrandSMS
- Website: https://brandsms.vn
- Tương tự ESMS

### Option 3: Twilio
- Website: https://www.twilio.com
- Phù hợp cho quốc tế
- Cần cài package: `dotnet add package Twilio`

## Bước 2: Cấu hình trong appsettings.json

Mở file `ICitizen/ICitizenAPI/ICitizen/appsettings.json` và cập nhật:

### Cấu hình ESMS (Khuyến nghị):

```json
{
  "Sms": {
    "Enabled": true,
    "Provider": "ESMS",
    "ESMS": {
      "ApiKey": "YOUR_ESMS_API_KEY",
      "ApiSecret": "YOUR_ESMS_API_SECRET",
      "BrandName": "ICITIZEN"
    }
  }
}
```

**Lấy API Key từ ESMS:**
1. Đăng nhập vào https://esms.vn
2. Vào mục **"API"** hoặc **"Tích hợp"**
3. Copy **API Key** và **API Secret**
4. Dán vào `appsettings.json`

### Cấu hình BrandSMS:

```json
{
  "Sms": {
    "Enabled": true,
    "Provider": "BrandSMS",
    "BrandSMS": {
      "ApiKey": "YOUR_BRANDSMS_API_KEY",
      "ApiUrl": "https://api.brandsms.vn/api/send"
    }
  }
}
```

### Cấu hình Twilio:

```json
{
  "Sms": {
    "Enabled": true,
    "Provider": "Twilio",
    "Twilio": {
      "AccountSid": "YOUR_TWILIO_ACCOUNT_SID",
      "AuthToken": "YOUR_TWILIO_AUTH_TOKEN",
      "FromNumber": "+1234567890"
    }
  }
}
```

**Lưu ý:** Với Twilio, cần cài package:
```bash
cd ICitizen/ICitizenAPI/ICitizen
dotnet add package Twilio
```

Sau đó uncomment code trong `SmsService.cs` (method `SendViaTwilio`).

## Bước 3: Tắt SMS trong Development (Tùy chọn)

Nếu muốn tắt SMS và chỉ log để test:

```json
{
  "Sms": {
    "Enabled": false,
    "Provider": "ESMS"
  }
}
```

Khi `Enabled: false`, OTP sẽ chỉ được log ra console, không gửi SMS thật.

## Bước 4: Test

1. Cập nhật `appsettings.json` với API key thật
2. Restart backend API
3. Test tính năng quên mật khẩu từ app
4. Kiểm tra điện thoại có nhận được SMS không

## Xử lý lỗi

### Lỗi: "ESMS API Key hoặc Secret chưa được cấu hình"
- Kiểm tra `appsettings.json` đã có `Sms:ESMS:ApiKey` và `Sms:ESMS:ApiSecret` chưa
- Đảm bảo không có khoảng trắng thừa

### Lỗi: "ESMS: Lỗi 101 - Invalid API Key"
- API Key hoặc Secret không đúng
- Kiểm tra lại trên trang quản trị ESMS

### Lỗi: "ESMS: Lỗi 102 - Not enough balance"
- Tài khoản ESMS hết tiền
- Nạp thêm tiền vào tài khoản

### SMS không đến
- Kiểm tra số điện thoại đúng format (0901234567 hoặc +84901234567)
- Kiểm tra log backend xem có lỗi gì không
- Kiểm tra tài khoản SMS còn tiền không

## Bảo mật

⚠️ **QUAN TRỌNG:** Không commit `appsettings.json` có chứa API key thật lên Git!

Tạo file `appsettings.Production.json` hoặc dùng **User Secrets**:

```bash
dotnet user-secrets set "Sms:ESMS:ApiKey" "YOUR_API_KEY"
dotnet user-secrets set "Sms:ESMS:ApiSecret" "YOUR_API_SECRET"
```

## Chi phí ước tính

- **ESMS**: ~200-300 VNĐ/SMS
- **BrandSMS**: Tương tự ESMS
- **Twilio**: ~$0.0075/SMS (~180 VNĐ/SMS)

Với 1000 OTP/tháng: ~200,000 - 300,000 VNĐ/tháng

