# Hướng dẫn tích hợp SMS Service

## Tổng quan

Tính năng quên mật khẩu sử dụng OTP gửi qua SMS. Hiện tại `SmsService` đang ở chế độ test (chỉ log). Để gửi SMS thật, bạn cần tích hợp với một dịch vụ SMS.

## Các dịch vụ SMS phổ biến

### 1. Twilio (Quốc tế)
- Website: https://www.twilio.com
- Hỗ trợ: Toàn cầu, có hỗ trợ Việt Nam
- Giá: ~$0.0075/SMS

### 2. AWS SNS (Amazon Simple Notification Service)
- Website: https://aws.amazon.com/sns/
- Hỗ trợ: Toàn cầu
- Giá: Theo region

### 3. Dịch vụ SMS Việt Nam
- **BrandSMS**: https://brandsms.vn
- **ESMS**: https://esms.vn
- **Viettel Post**: https://viettelpost.vn
- **VinaPhone**: API SMS
- **Mobifone**: API SMS

## Cách tích hợp

### Bước 1: Cài đặt package (nếu dùng Twilio)

```bash
dotnet add package Twilio
```

### Bước 2: Cập nhật `appsettings.json`

Thêm cấu hình SMS:

```json
{
  "Sms": {
    "Provider": "Twilio", // hoặc "ESMS", "BrandSMS", etc.
    "Twilio": {
      "AccountSid": "your_account_sid",
      "AuthToken": "your_auth_token",
      "FromNumber": "+1234567890"
    },
    "ESMS": {
      "ApiKey": "your_api_key",
      "ApiSecret": "your_api_secret",
      "BrandName": "ICITIZEN"
    }
  }
}
```

### Bước 3: Cập nhật `SmsService.cs`

#### Ví dụ với Twilio:

```csharp
using Twilio;
using Twilio.Rest.Api.V2010.Account;
using Twilio.Types;

public async Task<bool> SendSmsAsync(string phoneNumber, string message)
{
    try
    {
        var accountSid = _configuration["Sms:Twilio:AccountSid"];
        var authToken = _configuration["Sms:Twilio:AuthToken"];
        var fromNumber = _configuration["Sms:Twilio:FromNumber"];

        TwilioClient.Init(accountSid, authToken);

        // Format số điện thoại Việt Nam
        var formattedPhone = phoneNumber;
        if (!phoneNumber.StartsWith("+"))
        {
            if (phoneNumber.StartsWith("0"))
            {
                formattedPhone = "+84" + phoneNumber.Substring(1);
            }
            else
            {
                formattedPhone = "+84" + phoneNumber;
            }
        }

        var result = await MessageResource.CreateAsync(
            body: message,
            from: new PhoneNumber(fromNumber),
            to: new PhoneNumber(formattedPhone)
        );

        return result.Status != MessageResource.StatusEnum.Failed;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Lỗi khi gửi SMS đến {PhoneNumber}", phoneNumber);
        return false;
    }
}
```

#### Ví dụ với ESMS (Việt Nam):

```csharp
using System.Net.Http;
using System.Text.Json;

public async Task<bool> SendSmsAsync(string phoneNumber, string message)
{
    try
    {
        var apiKey = _configuration["Sms:ESMS:ApiKey"];
        var apiSecret = _configuration["Sms:ESMS:ApiSecret"];
        var brandName = _configuration["Sms:ESMS:BrandName"];

        using var httpClient = new HttpClient();
        
        var request = new
        {
            ApiKey = apiKey,
            ApiSecret = apiSecret,
            Phone = phoneNumber,
            Content = message,
            Brandname = brandName,
            SmsType = 2 // 2 = CSKH (Chăm sóc khách hàng)
        };

        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await httpClient.PostAsync("https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json", content);
        var responseContent = await response.Content.ReadAsStringAsync();

        // Parse response để kiểm tra thành công
        var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
        return result.GetProperty("CodeResult").GetString() == "100";
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Lỗi khi gửi SMS đến {PhoneNumber}", phoneNumber);
        return false;
    }
}
```

## API Endpoints

### 1. Gửi OTP
```
POST /api/Auth/forgot-password/send-otp
Body: { "phoneNumber": "0901234567" }
Response: { "message": "Mã OTP đã được gửi đến số điện thoại của bạn" }
```

### 2. Xác thực OTP
```
POST /api/Auth/forgot-password/verify-otp
Body: { "phoneNumber": "0901234567", "otp": "123456" }
Response: { "message": "Mã OTP hợp lệ", "verified": true }
```

### 3. Đặt lại mật khẩu
```
POST /api/Auth/forgot-password/reset
Body: { 
  "phoneNumber": "0901234567", 
  "otp": "123456", 
  "newPassword": "NewPass123@" 
}
Response: { "message": "Đặt lại mật khẩu thành công" }
```

## Bảo mật

1. **OTP hết hạn sau 5 phút**
2. **Cooldown 60 giây** giữa các lần gửi OTP
3. **Không trả về thông tin chi tiết** nếu số điện thoại không tồn tại (tránh enumeration attack)
4. **OTP chỉ sử dụng 1 lần** (xóa sau khi reset password thành công)

## Test

Trong môi trường development, `SmsService` sẽ log OTP ra console. Bạn có thể xem log để lấy mã OTP test.

Trong production, cần tích hợp với dịch vụ SMS thật.

