# Hướng dẫn lấy API Key từ ESMS

## Bước 1: Đăng nhập ESMS
1. Truy cập: https://account.esms.vn
2. Đăng nhập với tài khoản vừa đăng ký

## Bước 2: Lấy API Key và API Secret

### Cách 1: Từ menu "Tiện ích" (Utilities)
1. Vào menu bên trái, tìm **"Tiện ích"** (Utilities)
2. Click vào **"API"** hoặc **"Tích hợp API"**
3. Bạn sẽ thấy:
   - **API Key**: Một chuỗi dài (ví dụ: `ABC123XYZ...`)
   - **API Secret**: Một chuỗi dài khác (ví dụ: `DEF456UVW...`)

### Cách 2: Từ trang chính
1. Tìm menu **"API"** hoặc **"Tích hợp"** ở thanh menu trên
2. Click vào để xem thông tin API

### Cách 3: Nếu không thấy
1. Vào **"Trung tâm hỗ trợ"** (Support Center)
2. Liên hệ hotline: **0901 888 484** để được hướng dẫn

## Bước 3: Copy API Key và Secret
- Copy cả 2 chuỗi (API Key và API Secret)
- Lưu vào nơi an toàn (sẽ cần dán vào appsettings.json)

## Bước 4: Cập nhật appsettings.json

Mở file: `ICitizen/ICitizenAPI/ICitizen/appsettings.json`

Tìm phần `"Sms"` và cập nhật:

```json
"Sms": {
  "Enabled": true,
  "Provider": "ESMS",
  "ESMS": {
    "ApiKey": "DÁN_API_KEY_VÀO_ĐÂY",
    "ApiSecret": "DÁN_API_SECRET_VÀO_ĐÂY",
    "BrandName": "ICITIZEN"
  }
}
```

**Ví dụ:**
```json
"Sms": {
  "Enabled": true,
  "Provider": "ESMS",
  "ESMS": {
    "ApiKey": "ABC123XYZ789DEF456",
    "ApiSecret": "SECRET123XYZ789ABC456",
    "BrandName": "ICITIZEN"
  }
}
```

## Bước 5: Restart Backend
1. Dừng backend API (nếu đang chạy)
2. Chạy lại backend
3. Kiểm tra log xem có lỗi gì không

## Bước 6: Test
1. Mở app Flutter
2. Vào "Quên mật khẩu"
3. Nhập số điện thoại
4. Kiểm tra điện thoại có nhận được SMS không

## Lưu ý
- ✅ Đảm bảo tài khoản ESMS còn tiền (số dư > 0)
- ✅ Số điện thoại test phải là số thật, đã đăng ký trong hệ thống
- ✅ BrandName có thể để "ICITIZEN" hoặc tên khác (nếu đã đăng ký brandname)

## Xử lý lỗi

### Lỗi: "Invalid API Key"
- Kiểm tra lại API Key và Secret đã copy đúng chưa
- Không có khoảng trắng thừa ở đầu/cuối

### Lỗi: "Not enough balance"
- Nạp thêm tiền vào tài khoản ESMS
- Tối thiểu cần ~5,000 VNĐ để test

### SMS không đến
- Kiểm tra số điện thoại đúng format: 0901234567
- Kiểm tra log backend xem có lỗi gì
- Thử với số điện thoại khác

