# Debug lỗi 400 và 500 khi gửi OTP

## Lỗi 400 Bad Request

**Nguyên nhân có thể:**
1. Request body không đúng format
2. `phoneNumber` bị null hoặc rỗng
3. JSON không hợp lệ

**Cách kiểm tra:**
- Xem log backend: `SendOtp: Request body là null` hoặc `SendOtp: PhoneNumber rỗng`
- Kiểm tra request body trong Swagger/Postman

**Request đúng:**
```json
{
  "phoneNumber": "0901234567"
}
```

## Lỗi 500 Internal Server Error

**Nguyên nhân có thể:**
1. Lỗi khi gọi ESMS API
2. Lỗi khi parse response từ ESMS
3. Lỗi khi gửi SMS

**Cách kiểm tra log backend:**

### 1. Kiểm tra log khi gọi API

Tìm các dòng log sau trong console backend:

**Nếu thấy:**
```
ESMS API trả về lỗi HTTP: 400/500 - {...}
```
→ ESMS API có vấn đề

**Nếu thấy:**
```
Không thể parse response từ ESMS: {...}
```
→ Response từ ESMS không đúng format

**Nếu thấy:**
```
ESMS: Lỗi 101 - Invalid API Key
```
→ API Key hoặc Secret sai

**Nếu thấy:**
```
ESMS: Lỗi 102 - Not enough balance
```
→ Tài khoản ESMS hết tiền

**Nếu thấy:**
```
Không thể gửi SMS đến {PhoneNumber}
```
→ Có lỗi khi gửi SMS

### 2. Kiểm tra chi tiết

Mở console/terminal nơi chạy backend và tìm:
- Tất cả dòng có chứa "ESMS"
- Tất cả dòng có chứa "Error" hoặc "Lỗi"
- Tất cả dòng có chứa "Exception"

## Các bước debug

### Bước 1: Kiểm tra Request
```json
POST /api/Auth/forgot-password/send-otp
Content-Type: application/json

{
  "phoneNumber": "0901234567"
}
```

### Bước 2: Kiểm tra Log Backend
Sau khi gọi API, xem log backend và copy toàn bộ log liên quan đến:
- `SendOtp`
- `ESMS`
- `Error`
- `Exception`

### Bước 3: Kiểm tra API Key
Đảm bảo trong `appsettings.json`:
```json
"Sms": {
  "Enabled": true,
  "Provider": "ESMS",
  "ESMS": {
    "ApiKey": "2BEFE4FB17E934F295358C22467D1B",
    "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
    "BrandName": "ICITIZEN"
  }
}
```

### Bước 4: Test ESMS API trực tiếp

Test bằng Postman:
```
POST https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json
Content-Type: application/json

{
  "ApiKey": "2BEFE4FB17E934F295358C22467D1B",
  "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
  "Phone": "0901234567",
  "Content": "Test SMS",
  "Brandname": "",
  "SmsType": 2
}
```

**Lưu ý:** Thử để `Brandname` là `""` (rỗng) nếu chưa đăng ký.

## Yêu cầu

**Vui lòng copy toàn bộ log từ backend console khi bạn test gửi OTP và gửi cho tôi.**

Log sẽ giúp xác định chính xác lỗi ở đâu.

