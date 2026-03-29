# Hướng dẫn Debug SMS không gửi được

## Bước 1: Kiểm tra Backend đang chạy
1. Mở terminal/console nơi chạy backend
2. Xem log khi gửi OTP
3. Tìm các dòng có chứa:
   - "SMS gửi đến"
   - "ESMS"
   - "Lỗi"
   - "Error"

## Bước 2: Kiểm tra Log Backend

Khi bạn test gửi OTP, backend sẽ log ra. Tìm các thông tin sau:

### Nếu thấy lỗi:
```
ESMS: Lỗi 101 - Invalid API Key
```
→ API Key hoặc Secret không đúng

```
ESMS: Lỗi 102 - Not enough balance
```
→ Tài khoản ESMS hết tiền

```
ESMS API trả về lỗi: 400/401/500
```
→ Có lỗi khi gọi API

### Nếu không thấy log gì:
→ Backend có thể chưa restart sau khi cập nhật appsettings.json

## Bước 3: Restart Backend

**QUAN TRỌNG:** Sau khi sửa appsettings.json, PHẢI restart backend!

1. Dừng backend (Ctrl+C)
2. Chạy lại: `dotnet run` hoặc F5
3. Test lại

## Bước 4: Kiểm tra Format Số Điện Thoại

Số điện thoại phải đúng format:
- ✅ Đúng: `0901234567` hoặc `0912345678`
- ❌ Sai: `+84901234567` hoặc `84901234567` (không có dấu + hoặc 84 ở đầu)

## Bước 5: Test API ESMS Trực Tiếp

Có thể test API ESMS bằng Postman hoặc curl:

### Dùng curl:
```bash
curl -X POST https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json \
  -H "Content-Type: application/json" \
  -d '{
    "ApiKey": "2BEFE4FB17E934F295358C22467D1B",
    "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
    "Phone": "0901234567",
    "Content": "Test SMS",
    "Brandname": "ICITIZEN",
    "SmsType": 2
  }'
```

### Hoặc dùng Postman:
- Method: POST
- URL: `https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json`
- Headers: `Content-Type: application/json`
- Body (JSON):
```json
{
  "ApiKey": "2BEFE4FB17E934F295358C22467D1B",
  "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
  "Phone": "0901234567",
  "Content": "Test SMS",
  "Brandname": "ICITIZEN",
  "SmsType": 2
}
```

## Bước 6: Kiểm tra Response

Response thành công sẽ có:
```json
{
  "CodeResult": "100",
  "CountRegenerate": 0,
  "SMSID": "..."
}
```

Response lỗi sẽ có:
```json
{
  "CodeResult": "101",
  "ErrorMessage": "Invalid API Key"
}
```

## Các lỗi thường gặp:

### CodeResult = "101"
→ API Key hoặc Secret sai
→ Kiểm tra lại trên trang ESMS

### CodeResult = "102"
→ Hết tiền
→ Nạp thêm tiền vào tài khoản ESMS

### CodeResult = "103"
→ Brandname chưa được đăng ký
→ Đăng ký brandname hoặc để trống

### Không có response
→ Kiểm tra internet
→ Kiểm tra URL API có đúng không

