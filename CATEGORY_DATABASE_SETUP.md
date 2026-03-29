# Hướng dẫn lưu Categories vào Database

## Tình trạng hiện tại

✅ **Category đã được lưu vào database** khi tạo/cập nhật amenity:
- Khi admin tạo hoặc cập nhật tiện ích, category được gửi lên server qua field `category` trong request body
- Backend nhận category và lưu vào bảng `Amenities` (hoặc tương đương)

❌ **Danh sách categories mặc định chưa có trong database**:
- Hiện tại danh sách categories chỉ hardcoded trong code Flutter
- Chưa có bảng riêng để quản lý categories

## Giải pháp

### Option 1: Lưu categories vào bảng riêng (Khuyến nghị)

Tạo bảng `Categories` trong database:

```sql
CREATE TABLE Categories (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(500),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE()
);

-- Insert categories mặc định
INSERT INTO Categories (Name, Description) VALUES
('Thể thao & Fitness', 'Các tiện ích thể thao và fitness'),
('Giải trí', 'Khu vực giải trí và vui chơi'),
('Ăn uống', 'Nhà hàng, quán ăn, bar'),
('Spa & Wellness', 'Spa, massage, chăm sóc sức khỏe'),
('Hồ bơi', 'Hồ bơi trong nhà và ngoài trời'),
('Khu vui chơi trẻ em', 'Khu vui chơi dành cho trẻ em'),
('Phòng họp & Sự kiện', 'Phòng họp, sảnh sự kiện'),
('Thư viện', 'Không gian đọc sách và học tập'),
('Karaoke', 'Phòng karaoke'),
('Sân tennis', 'Sân tennis'),
('Sân bóng rổ', 'Sân bóng rổ'),
('Phòng gym', 'Phòng tập gym'),
('Yoga & Pilates', 'Phòng yoga và pilates'),
('BBQ & Nướng', 'Khu vực BBQ và nướng'),
('Khu vườn', 'Khu vườn, không gian xanh'),
('Khác', 'Các tiện ích khác');
```

### Option 2: Backend API Endpoints cần tạo

#### 1. GET /api/Amenities/categories
Lấy danh sách tất cả categories từ database:

```csharp
[HttpGet("categories")]
public async Task<ActionResult<List<string>>> GetCategories()
{
    var categories = await _context.Categories
        .Where(c => c.IsActive)
        .OrderBy(c => c.Name)
        .Select(c => c.Name)
        .ToListAsync();
    
    return Ok(categories);
}
```

#### 2. POST /api/Amenities/initialize-categories (Optional)
Khởi tạo categories mặc định nếu chưa có:

```csharp
[HttpPost("initialize-categories")]
public async Task<IActionResult> InitializeCategories([FromBody] List<string> categories)
{
    foreach (var categoryName in categories)
    {
        var exists = await _context.Categories
            .AnyAsync(c => c.Name == categoryName);
        
        if (!exists)
        {
            _context.Categories.Add(new Category
            {
                Name = categoryName,
                IsActive = true
            });
        }
    }
    
    await _context.SaveChangesAsync();
    return Ok();
}
```

### Option 3: Đảm bảo Category được lưu khi tạo Amenity

Backend cần đảm bảo khi nhận request tạo/cập nhật amenity, category được lưu vào database:

```csharp
[HttpPost]
public async Task<ActionResult<Amenity>> CreateAmenity([FromBody] CreateAmenityDto dto)
{
    // Validate category tồn tại trong database
    var categoryExists = await _context.Categories
        .AnyAsync(c => c.Name == dto.Category && c.IsActive);
    
    if (!categoryExists && !string.IsNullOrEmpty(dto.Category))
    {
        // Tự động tạo category mới nếu chưa có
        _context.Categories.Add(new Category
        {
            Name = dto.Category,
            IsActive = true
        });
        await _context.SaveChangesAsync();
    }
    
    var amenity = new Amenity
    {
        Name = dto.Name,
        Category = dto.Category, // Lưu category vào database
        // ... các field khác
    };
    
    _context.Amenities.Add(amenity);
    await _context.SaveChangesAsync();
    
    return Ok(amenity);
}
```

## Kiểm tra

Sau khi implement backend:

1. **Kiểm tra categories được lưu vào database:**
   ```sql
   SELECT * FROM Categories;
   ```

2. **Kiểm tra amenity có category:**
   ```sql
   SELECT Id, Name, Category FROM Amenities;
   ```

3. **Test API:**
   - GET `/api/Amenities/categories` - Trả về danh sách categories
   - POST `/api/Amenities` với category - Category được lưu vào database

## Lưu ý

- Flutter app đã sẵn sàng: Code đã gửi category lên server và có thể lấy categories từ API
- Backend cần implement các endpoint trên để hoàn thiện tính năng
- Nếu backend chưa có endpoint `/api/Amenities/categories`, app sẽ dùng danh sách mặc định hardcoded

