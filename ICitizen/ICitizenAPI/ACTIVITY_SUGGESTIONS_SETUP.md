# Hệ thống Gợi ý Hoạt động (Activity Suggestions)

## Tổng quan

Hệ thống gợi ý hoạt động tự động dựa trên:
- Hóa đơn chưa thanh toán (Bills)
- Sự kiện cộng đồng theo tầng/toà (Community Events)
- Thời tiết thực tế (Weather API)
- Thông tin cư dân (tuổi, phong cách sống, tầng/toà)
- Thời gian trong ngày và ngày trong tuần

## Cấu trúc

### Entities

1. **Activity** - 22 hoạt động được seed sẵn với tags chuẩn hóa
2. **Bill** - Hóa đơn chưa thanh toán (Service, Electric, Water, Parking)
3. **CommunityEvent** - Sự kiện cộng đồng theo tầng/toà
4. **ResidentProfile** - Đã mở rộng với: Age, LifeStyle, Building, Floor

### Services

1. **IWeatherService / OpenWeatherService** - Lấy thời tiết từ OpenWeatherMap API
2. **IRuleBasedSuggestionService / RuleBasedSuggestionService** - Logic tính điểm và gợi ý

### API Endpoints

- `GET /api/Suggestions/my-suggestions` - Lấy gợi ý cho cư dân hiện tại
- `GET /api/Suggestions/resident/{residentId}` - Lấy gợi ý cho cư dân cụ thể (Manager/Admin)

## Tags chuẩn hóa

### Theo loại việc:
- `tai_chinh` - tài chính, thanh toán
- `bat_buoc` - việc bắt buộc
- `suc_khoe` - sức khỏe, vận động
- `giai_tri` - giải trí
- `su_kien` - sự kiện
- `hoat_dong_gia_dinh` - hoạt động gia đình
- `tre_em` - liên quan trẻ em
- `cong_viec` - việc nhà / giấy tờ / quản lý
- `hoc_tap` - học / làm việc yên tĩnh
- `bao_tri` - bảo trì
- `an_toan`, `an_ninh` - an toàn / an ninh

### Theo địa điểm:
- `ngoai_troi` - ngoài trời
- `trong_nha` - trong nhà

### Theo thời gian:
- `buoi_sang` - buổi sáng
- `buoi_chieu` - buổi chiều
- `buoi_toi` - buổi tối
- `cuoi_tuan` - cuối tuần

### Theo đối tượng:
- `nguoi_gia` - người già
- `cong_dong` - ảnh hưởng cả cộng đồng

### Khác:
- `mua_sam` - mua sắm
- `dich_vu` - dịch vụ
- `social` - giao lưu

## Cài đặt

### 1. Migration

Chạy migration để tạo các bảng mới:

```bash
dotnet ef migrations add AddActivitySuggestions
dotnet ef database update
```

### 2. Cấu hình Weather API

Trong `appsettings.json`, thêm hoặc cập nhật:

```json
"WeatherSettings": {
  "City": "Ho Chi Minh",
  "ApiKey": "YOUR_OPENWEATHER_API_KEY"
}
```

Lấy API key miễn phí tại: https://openweathermap.org/api

**Lưu ý**: Nếu không có API key, hệ thống sẽ fallback về thời tiết mặc định (sunny, 32°C).

### 3. Seed dữ liệu

Dữ liệu seed đã được cấu hình trong `OnModelCreating`:
- 22 Activities với tags đầy đủ
- 2 Community Events mẫu (tòa A, tầng 1 và tầng 5)

Bills sẽ được seed tự động khi app khởi động (nếu chưa có).

## Logic tính điểm

### 1. Hóa đơn (Bill)
- Service bill chưa thanh toán: +100 điểm cho PAY_SERVICE_BILL
- Electric bill chưa thanh toán: +90 điểm cho PAY_ELECTRIC_BILL
- Water bill chưa thanh toán: +80 điểm cho PAY_WATER_BILL
- Parking chưa đăng ký: +80 điểm cho REGISTER_PARKING

### 2. Thời tiết
- Mưa + hoạt động ngoài trời: -40 điểm
- Nắng nóng (≥30°C) + bơi: +30 điểm
- Mưa + hoạt động trong nhà: +10 điểm
- Mưa + đặt đồ online: +25 điểm

### 3. Thời gian
- Buổi sáng (6-12h): +20 cho tag `buoi_sang`, -10 cho `buoi_chieu`/`buoi_toi`
- Buổi chiều (12-18h): +20 cho tag `buoi_chieu`, -5 cho `buoi_sang`
- Buổi tối (18h+): +20 cho tag `buoi_toi`, -10 cho `buoi_sang`/`buoi_chieu`
- Cuối tuần: +15 cho tag `cuoi_tuan`, -10 nếu không phải cuối tuần

### 4. Sự kiện
- Có sự kiện hôm nay: +40 cho JOIN_WEEKEND_EVENT
- Sự kiện trẻ em + phong cách gia đình: +50 cho JOIN_KIDS_WORKSHOP

### 5. Phong cách sống
- `gia_dinh` + hoạt động gia đình: +15 điểm
- `nguoi_gia` + hoạt động người già: +20 điểm

### 6. Tuổi tác
- ≥60 tuổi + hoạt động người già: +15 điểm

### 7. Bắt buộc
- Tag `bat_buoc`: +30 điểm

## Sử dụng API

### Lấy gợi ý cho cư dân hiện tại

```http
GET /api/Suggestions/my-suggestions
Authorization: Bearer {token}
```

Response:
```json
{
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
  ]
}
```

### Lấy gợi ý cho cư dân khác (Manager/Admin)

```http
GET /api/Suggestions/resident/{residentId}
Authorization: Bearer {token}
```

## Cập nhật thông tin cư dân

Để hệ thống gợi ý chính xác hơn, cập nhật thông tin cư dân:

```csharp
resident.Age = 35;
resident.LifeStyle = "gia_dinh"; // hoặc "doc_than", "nguoi_gia"
resident.Building = "A";
resident.Floor = 5;
```

## Tạo Bill mới

```csharp
var bill = new Bill
{
    ResidentProfileId = residentId,
    Type = "Service", // hoặc "Electric", "Water", "Parking"
    DueDate = DateTime.Today.AddDays(7),
    IsPaid = false
};
db.Bills.Add(bill);
await db.SaveChangesAsync();
```

## Tạo Community Event

```csharp
var evt = new CommunityEvent
{
    Title = "Sự kiện cộng đồng",
    Description = "...",
    StartTime = DateTime.Today.AddHours(19),
    EndTime = DateTime.Today.AddHours(21),
    Building = "A",
    Floor = 1, // null = sảnh chung
    Tags = "su_kien,social,hoat_dong_gia_dinh"
};
db.CommunityEvents.Add(evt);
await db.SaveChangesAsync();
```

## Mở rộng

Để thêm rule mới, chỉnh sửa method `ScoreActivities` trong `RuleBasedSuggestionService.cs`.

