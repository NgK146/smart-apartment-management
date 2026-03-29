# Hướng dẫn nạp tiền vào tài khoản ESMS

## Vấn đề
Từ ảnh bạn gửi, tôi thấy:
- **Tài khoản chính: 00 ₫** ← **KHÔNG CÓ TIỀN**
- **Tài khoản khuyến mãi: 5,000 ₫** ← Có tiền nhưng có thể không dùng được

ESMS thường yêu cầu **tài khoản chính phải có tiền** để gửi SMS qua API.

## Cách nạp tiền

### Bước 1: Vào trang nạp tiền
1. Đăng nhập vào https://account.esms.vn
2. Tìm menu **"Nạp tiền"** hoặc **"Thanh toán"**
3. Hoặc click vào số dư **"00 ₫"** ở góc trên

### Bước 2: Chọn phương thức nạp tiền
ESMS thường hỗ trợ:
- **Chuyển khoản ngân hàng**
- **Ví điện tử** (MoMo, ZaloPay, etc.)
- **Thẻ cào** (có thể)

### Bước 3: Nạp tiền
1. Chọn số tiền muốn nạp (tối thiểu thường là 50,000 - 100,000 VNĐ)
2. Chọn phương thức thanh toán
3. Hoàn tất thanh toán

### Bước 4: Chờ xác nhận
- Nếu chuyển khoản: Thường mất 5-15 phút
- Nếu ví điện tử: Thường ngay lập tức

## Sau khi nạp tiền

1. **Kiểm tra số dư:**
   - Tài khoản chính phải > 0₫
   - Thường cần tối thiểu 10,000 - 20,000₫ để test

2. **Restart backend:**
   - Dừng backend (Ctrl+C)
   - Chạy lại: `dotnet run` hoặc F5

3. **Test lại API:**
   - Gọi API gửi OTP
   - Kiểm tra log backend
   - Kiểm tra điện thoại có nhận được SMS không

## Lưu ý

- ✅ **Tài khoản chính** phải có tiền (không phải tài khoản khuyến mãi)
- ✅ Giá SMS thường: **200-300 VNĐ/SMS**
- ✅ Nạp tối thiểu: **50,000 - 100,000 VNĐ** (tùy ESMS)
- ✅ Sau khi nạp, đợi vài phút để hệ thống cập nhật số dư

## Nếu vẫn lỗi sau khi nạp tiền

1. **Kiểm tra lại API Key/Secret:**
   - Đảm bảo đã cập nhật đúng trong `appsettings.json`
   - Restart backend sau khi sửa

2. **Test trực tiếp API ESMS:**
   - Dùng Postman test xem API có hoạt động không
   - Xem response có CodeResult: "100" không

3. **Liên hệ hỗ trợ ESMS:**
   - Hotline: **0901 888 484**
   - Hoặc chat trực tiếp trên trang ESMS

