# Hướng dẫn Test API Gợi ý Hoạt động

## 1. Chạy API Server

```bash
cd ICitizen/ICitizenAPI/ICitizen
dotnet run
```

API sẽ chạy tại: `https://localhost:7xxx` hoặc `http://localhost:5xxx`

## 2. Test Endpoints (Không cần Auth)

### 2.1. Lấy danh sách Residents để test

```http
GET http://localhost:5000/api/Suggestions/test/residents
```

Response mẫu:
```json
{
  "residents": [
    {
      "id": "guid",
      "apartmentCode": "A101",
      "building": "A",
      "floor": 1,
      "age": null,
      "lifeStyle": null,
      "userId": "user-id"
    }
  ],
  "count": 1
}
```

### 2.2. Test gợi ý cho một Resident cụ thể

```http
GET http://localhost:5000/api/Suggestions/test/{residentId}
```

Ví dụ:
```http
GET http://localhost:5000/api/Suggestions/test/12345678-1234-1234-1234-123456789012
```

Response mẫu:
```json
{
  "resident": {
    "id": "guid",
    "apartmentCode": "A101",
    "building": "A",
    "floor": 1,
    "age": 35,
    "lifeStyle": "gia_dinh"
  },
  "suggestions": [
    {
      "id": "guid",
      "code": "PAY_SERVICE_BILL",
      "title": "Thanh toán phí dịch vụ tháng này",
      "description": "...",
      "tags": "tai_chinh,bat_buoc,buoi_sang",
      "score": 130
    },
    ...
  ],
  "summary": {
    "total": 22,
    "topScore": 130,
    "averageScore": 45.5
  }
}
```

## 3. Test với Postman/Thunder Client

### Bước 1: Lấy danh sách Residents
- Method: `GET`
- URL: `http://localhost:5000/api/Suggestions/test/residents`
- Headers: Không cần

### Bước 2: Copy một Resident ID và test gợi ý
- Method: `GET`
- URL: `http://localhost:5000/api/Suggestions/test/{residentId}`
- Headers: Không cần

## 4. Test với PowerShell

Tạo file `test_suggestions.ps1`:

```powershell
$baseUrl = "http://localhost:5000"

# 1. Lấy danh sách residents
Write-Host "=== Lấy danh sách Residents ===" -ForegroundColor Green
$residentsResponse = Invoke-RestMethod -Uri "$baseUrl/api/Suggestions/test/residents" -Method Get
Write-Host "Tìm thấy $($residentsResponse.count) residents" -ForegroundColor Yellow
$residentsResponse.residents | Format-Table

# 2. Test với resident đầu tiên
if ($residentsResponse.residents.Count -gt 0) {
    $residentId = $residentsResponse.residents[0].id
    Write-Host "`n=== Test gợi ý cho Resident: $residentId ===" -ForegroundColor Green
    
    $suggestionsResponse = Invoke-RestMethod -Uri "$baseUrl/api/Suggestions/test/$residentId" -Method Get
    
    Write-Host "Resident Info:" -ForegroundColor Cyan
    $suggestionsResponse.resident | Format-List
    
    Write-Host "`nTop 5 Suggestions:" -ForegroundColor Cyan
    $suggestionsResponse.suggestions | Select-Object -First 5 | Format-Table code, title, score
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    $suggestionsResponse.summary | Format-List
}
```

Chạy:
```powershell
.\test_suggestions.ps1
```

## 5. Test với cURL

```bash
# Lấy danh sách residents
curl http://localhost:5000/api/Suggestions/test/residents

# Test gợi ý (thay {residentId} bằng ID thực)
curl http://localhost:5000/api/Suggestions/test/{residentId}
```

## 6. Chuẩn bị dữ liệu test

### 6.1. Cập nhật thông tin Resident

Có thể cập nhật trực tiếp trong database hoặc tạo endpoint để update:

```sql
-- Cập nhật thông tin resident để test
UPDATE ResidentProfiles 
SET Age = 35, 
    LifeStyle = 'gia_dinh',
    Building = 'A',
    Floor = 5
WHERE Id = 'your-resident-id';
```

### 6.2. Tạo Bill để test

```sql
-- Tạo bill chưa thanh toán
INSERT INTO Bills (Id, ResidentProfileId, Type, DueDate, IsPaid, CreatedAtUtc, IsDeleted)
VALUES (NEWID(), 'your-resident-id', 'Service', GETDATE(), 0, GETUTCDATE(), 0);
```

## 7. Test với Auth (Production)

### 7.1. Đăng nhập để lấy token

```http
POST http://localhost:5000/api/Auth/login
Content-Type: application/json

{
  "username": "your-username",
  "password": "your-password"
}
```

### 7.2. Gọi API với token

```http
GET http://localhost:5000/api/Suggestions/my-suggestions
Authorization: Bearer {token}
```

## 8. Kiểm tra kết quả

### Các yếu tố ảnh hưởng đến điểm số:

1. **Bills chưa thanh toán**: 
   - Service: +100
   - Electric: +90
   - Water: +80
   - Parking: +80

2. **Thời tiết**:
   - Mưa + ngoài trời: -40
   - Nắng nóng + bơi: +30
   - Mưa + trong nhà: +10

3. **Thời gian**:
   - Buổi sáng: +20 cho tag `buoi_sang`
   - Buổi chiều: +20 cho tag `buoi_chieu`
   - Buổi tối: +20 cho tag `buoi_toi`
   - Cuối tuần: +15 cho tag `cuoi_tuan`

4. **Sự kiện**:
   - Có sự kiện hôm nay: +40 cho JOIN_WEEKEND_EVENT

5. **Phong cách sống**:
   - `gia_dinh`: +15 cho hoạt động gia đình
   - `nguoi_gia`: +20 cho hoạt động người già

## 9. Troubleshooting

### Lỗi: "Resident profile not found"
- Kiểm tra xem có ResidentProfile nào trong database không
- Đảm bảo UserId đúng với user đang đăng nhập

### Lỗi: "No suggestions returned"
- Kiểm tra xem có Activities trong database không (nên có 22)
- Kiểm tra logs để xem có lỗi gì không

### Gợi ý không chính xác
- Kiểm tra thông tin Resident (Age, LifeStyle, Building, Floor)
- Kiểm tra Bills chưa thanh toán
- Kiểm tra Community Events hôm nay
- Kiểm tra Weather API (hoặc fallback)

