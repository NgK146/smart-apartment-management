# Hướng dẫn tạo Migration và Update Database cho Categories

## Bước 1: Tạo Migration

Mở terminal/PowerShell trong thư mục `ICitizen/ICitizenAPI/ICitizen` và chạy:

```bash
dotnet ef migrations add AddCategoriesTable
```

Hoặc nếu bạn đang ở thư mục root của solution:

```bash
cd ICitizen/ICitizenAPI/ICitizen
dotnet ef migrations add AddCategoriesTable --project ICitizen.csproj
```

## Bước 2: Kiểm tra Migration đã được tạo

Migration sẽ được tạo trong thư mục `Migrations/` với tên như:
- `YYYYMMDDHHMMSS_AddCategoriesTable.cs`
- `YYYYMMDDHHMMSS_AddCategoriesTable.Designer.cs`

## Bước 3: Thêm Seed Data vào Migration

Sau khi migration được tạo, bạn cần mở file migration và thêm seed data vào method `Up()`:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    // ... code tạo bảng Categories ...

    // Thêm seed data cho categories
    migrationBuilder.InsertData(
        table: "Categories",
        columns: new[] { "Id", "Name", "Description", "Icon", "IsActive", "DisplayOrder", "CreatedAtUtc", "IsDeleted" },
        values: new object[,]
        {
            { Guid.NewGuid(), "Thể thao & Fitness", "Các tiện ích thể thao và fitness như phòng gym, sân tennis, bóng rổ", "🏋️", true, 1, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Giải trí", "Khu vực giải trí và vui chơi như karaoke, game room", "🎮", true, 2, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Ăn uống", "Nhà hàng, quán ăn, bar, cafe trong tòa nhà", "🍽️", true, 3, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Spa & Wellness", "Spa, massage, phòng xông hơi, chăm sóc sức khỏe", "💆", true, 4, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Hồ bơi", "Hồ bơi trong nhà và ngoài trời", "🏊", true, 5, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Khu vui chơi trẻ em", "Khu vui chơi dành cho trẻ em", "🎠", true, 6, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Phòng họp & Sự kiện", "Phòng họp, sảnh sự kiện, phòng tiệc", "🎉", true, 7, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Thư viện", "Không gian đọc sách và học tập", "📚", true, 8, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Karaoke", "Phòng karaoke riêng", "🎤", true, 9, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Sân tennis", "Sân tennis trong nhà hoặc ngoài trời", "🎾", true, 10, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Sân bóng rổ", "Sân bóng rổ", "🏀", true, 11, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Phòng gym", "Phòng tập gym đầy đủ thiết bị", "💪", true, 12, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Yoga & Pilates", "Phòng yoga và pilates", "🧘", true, 13, DateTime.UtcNow, false },
            { Guid.NewGuid(), "BBQ & Nướng", "Khu vực BBQ và nướng ngoài trời", "🔥", true, 14, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Khu vườn", "Khu vườn, không gian xanh, vườn thượng", "🌳", true, 15, DateTime.UtcNow, false },
            { Guid.NewGuid(), "Khác", "Các tiện ích khác", "📦", true, 99, DateTime.UtcNow, false }
        });
}
```

## Bước 4: Update Database

Chạy migration để cập nhật database:

```bash
dotnet ef database update
```

Hoặc:

```bash
dotnet ef database update AddCategoriesTable --project ICitizen.csproj
```

## Bước 5: Kiểm tra

Sau khi update database thành công, kiểm tra:

1. Bảng `Categories` đã được tạo
2. 16 categories đã được insert vào database
3. Cột `Category` trong bảng `Amenities` đã tồn tại (hoặc được tạo)

## Lưu ý

- Nếu cột `Category` trong bảng `Amenities` đã tồn tại, migration sẽ không tạo lại
- Nếu muốn thêm categories mới sau này, có thể dùng API `POST /api/Categories` hoặc thêm vào migration tiếp theo
- Migration sẽ tự động tạo index cho `Category` trong bảng `Amenities` để tìm kiếm nhanh hơn

