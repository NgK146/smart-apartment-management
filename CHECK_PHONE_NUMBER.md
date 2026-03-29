# Kiểm tra số điện thoại trong database

## Vấn đề
Response `"Nếu số điện thoại tồn tại, mã OTP đã được gửi"` có nghĩa là:
- ❌ Số điện thoại **KHÔNG TỒN TẠI** trong database
- ❌ Do đó **KHÔNG CÓ SMS** nào được gửi

## Cách kiểm tra số điện thoại có trong database

### Cách 1: Kiểm tra qua SQL Server
1. Mở SQL Server Management Studio
2. Kết nối đến database `ICitizenDb`
3. Chạy query:
```sql
SELECT UserName, PhoneNumber, Email, FullName 
FROM AspNetUsers 
WHERE PhoneNumber = '0569824924'
```

### Cách 2: Kiểm tra qua Swagger/API
1. Gọi API: `GET /api/Users` (nếu có)
2. Hoặc tìm user qua username/email

### Cách 3: Kiểm tra log backend
Khi bạn gọi API, backend sẽ log:
```
Yêu cầu gửi OTP cho số điện thoại không tồn tại: 0569824924
```

## Giải pháp

### Option 1: Tạo user mới với số điện thoại này
1. Đăng ký user mới qua API `POST /api/Auth/register`
2. Body:
```json
{
  "username": "testuser",
  "password": "123456",
  "phoneNumber": "0569824924",
  "email": "test@example.com",
  "fullName": "Test User",
  "desiredRole": "Resident"
}
```

### Option 2: Cập nhật số điện thoại cho user hiện có
1. Tìm user hiện có trong database
2. Cập nhật `PhoneNumber` = `0569824924`

### Option 3: Test với số điện thoại đã có
1. Kiểm tra database xem có số nào
2. Test với số đó

## Sau khi có user với số điện thoại

1. Test lại API `POST /api/Auth/forgot-password/send-otp`
2. Response sẽ khác: `"Mã OTP đã được gửi đến số điện thoại của bạn"`
3. Kiểm tra log backend sẽ thấy:
   ```
   📱 Gửi SMS ESMS đến: 0569824924
   ESMS Response: 200 - {...}
   ✅ ESMS: Gửi SMS thành công
   ```
4. Kiểm tra điện thoại sẽ nhận được SMS OTP

