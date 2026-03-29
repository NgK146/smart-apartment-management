# Sửa lỗi ESMS: Authorize Failed (Code 101)

## Vấn đề
ESMS trả về lỗi `CodeResult: 101 - Authorize Failed`, có nghĩa là:
- ❌ API Key hoặc API Secret **KHÔNG ĐÚNG**
- ❌ Hoặc có khoảng trắng thừa ở đầu/cuối

## Cách sửa

### Bước 1: Kiểm tra lại API Key trên ESMS
1. Đăng nhập vào https://account.esms.vn
2. Vào menu **"Tiện ích"** → **"API"** hoặc **"Tích hợp API"**
3. Copy lại **API Key** và **API Secret** (copy cẩn thận, không có khoảng trắng)

### Bước 2: Cập nhật appsettings.json
1. Mở file: `ICitizen/ICitizenAPI/ICitizen/appsettings.json`
2. Tìm phần `"Sms"` → `"ESMS"`
3. **XÓA** toàn bộ API Key và Secret cũ
4. **DÁN** lại API Key và Secret mới (đảm bảo không có khoảng trắng thừa)

**Ví dụ:**
```json
"ESMS": {
  "ApiKey": "2BEFE4FB17E934F295358C22467D1B",  ← Copy lại từ ESMS
  "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",  ← Copy lại từ ESMS
  "BrandName": "ICITIZEN"
}
```

### Bước 3: Kiểm tra
- ✅ Không có khoảng trắng ở đầu/cuối
- ✅ Không có dấu ngoặc kép thừa
- ✅ Độ dài đúng (thường là 30-32 ký tự)

### Bước 4: Restart Backend
1. Dừng backend (Ctrl+C)
2. Chạy lại: `dotnet run` hoặc F5
3. Test lại API

## Lưu ý

### Nếu vẫn lỗi sau khi copy lại:
1. **Kiểm tra tài khoản ESMS:**
   - Đăng nhập vào https://account.esms.vn
   - Kiểm tra số dư còn tiền không
   - Kiểm tra API Key có bị vô hiệu hóa không

2. **Tạo API Key mới:**
   - Trên trang ESMS, tìm nút **"Tạo API Key mới"** hoặc **"Reset API Key"**
   - Tạo mới và copy lại

3. **Liên hệ hỗ trợ ESMS:**
   - Hotline: 0901 888 484
   - Hoặc chat trực tiếp trên trang ESMS

## Test sau khi sửa

Sau khi cập nhật và restart, test lại. Log sẽ hiển thị:

**Thành công:**
```
ESMS Response: OK - {"CodeResult":"100","SMSID":"..."}
✅ ESMS: Gửi SMS thành công. SMSID: ...
```

**Vẫn lỗi:**
```
ESMS Response: OK - {"CodeResult":"101","ErrorMessage":"Authorize Failed"}
❌ ESMS: Lỗi 101 - Authorize Failed
```
→ Cần kiểm tra lại API Key/Secret hoặc tạo mới

