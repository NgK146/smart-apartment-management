# Test ESMS API trực tiếp

## Vấn đề
Vẫn còn lỗi 101 - Authorize Failed sau khi cập nhật API Key.

## Test trực tiếp bằng Postman/curl

### Dùng Postman:
1. Method: **POST**
2. URL: `https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/`
3. Headers:
   - `Content-Type: application/json`
4. Body (raw JSON):
```json
{
  "ApiKey": "EABA23C04DA2ADDA85C25650C416E6",
  "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
  "Phone": "0569824924",
  "Content": "Test SMS",
  "Brandname": "HNK_INTERTAMENT",
  "SmsType": 2
}
```

### Hoặc dùng curl:
```bash
curl -X POST "https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/" \
  -H "Content-Type: application/json" \
  -d '{
    "ApiKey": "EABA23C04DA2ADDA85C25650C416E6",
    "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
    "Phone": "0569824924",
    "Content": "Test SMS",
    "Brandname": "HNK_INTERTAMENT",
    "SmsType": 2
  }'
```

## Kiểm tra Response

### Nếu thành công:
```json
{
  "CodeResult": "100",
  "SMSID": "...",
  "CountRegenerate": 0
}
```

### Nếu vẫn lỗi 101:
- Kiểm tra lại API Key/Secret trên trang ESMS
- Có thể cần tạo API Key mới
- Hoặc liên hệ hỗ trợ ESMS: 0901 888 484

## Lưu ý

1. **Thử để Brandname rỗng:**
```json
{
  "ApiKey": "EABA23C04DA2ADDA85C25650C416E6",
  "ApiSecret": "D4135EDA988D004B649AAE8CD5962C",
  "Phone": "0569824924",
  "Content": "Test SMS",
  "Brandname": "",
  "SmsType": 2
}
```

2. **Kiểm tra số điện thoại:**
- Phải đúng format: `0569824924` (không có dấu +84)
- Phải là số thật, đã kích hoạt

3. **Kiểm tra tài khoản ESMS:**
- Số dư còn tiền không
- API Key có bị vô hiệu hóa không

