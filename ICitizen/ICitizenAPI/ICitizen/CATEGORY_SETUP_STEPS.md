# Hướng dẫn Setup Categories với Code First

## Các file đã được tạo/cập nhật

### 1. Domain Model
- ✅ `Domain/Category.cs` - Model cho Category

### 2. DbContext
- ✅ `Data/ApplicationDbContext.cs` - Đã thêm `DbSet<Category>` và cấu hình

### 3. Controllers
- ✅ `Controllers/CategoriesController.cs` - API controller cho Categories
- ✅ `Controllers/AmenitiesController.cs` - Đã cập nhật để hỗ trợ filter category

### 4. Common
- ✅ `Common/PagedResult.cs` - Đã thêm `Category` vào QueryParameters

## Các bước thực hiện

### Bước 1: Tạo Migration

Mở terminal trong thư mục `ICitizen/ICitizenAPI/ICitizen`:

```powershell
dotnet ef migrations add AddCategoriesTable
```

### Bước 2: Thêm Seed Data vào Migration

Sau khi migration được tạo, mở file migration (ví dụ: `Migrations/20250101120000_AddCategoriesTable.cs`) và thêm seed data vào method `Up()`:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.CreateTable(
        name: "Categories",
        columns: table => new
        {
            Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
            Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
            Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
            Icon = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
            IsActive = table.Column<bool>(type: "bit", nullable: false),
            DisplayOrder = table.Column<int>(type: "int", nullable: false),
            CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
            UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
            IsDeleted = table.Column<bool>(type: "bit", nullable: false)
        },
        constraints: table =>
        {
            table.PrimaryKey("PK_Categories", x => x.Id);
        });

    migrationBuilder.CreateIndex(
        name: "IX_Categories_Name",
        table: "Categories",
        column: "Name",
        unique: true);

    migrationBuilder.CreateIndex(
        name: "IX_Categories_IsActive_DisplayOrder",
        table: "Categories",
        columns: new[] { "IsActive", "DisplayOrder" });

    // THÊM SEED DATA VÀO ĐÂY
    var categories = new[]
    {
        new { Id = Guid.NewGuid(), Name = "Thể thao & Fitness", Description = "Các tiện ích thể thao và fitness như phòng gym, sân tennis, bóng rổ", Icon = "🏋️", IsActive = true, DisplayOrder = 1, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Giải trí", Description = "Khu vực giải trí và vui chơi như karaoke, game room", Icon = "🎮", IsActive = true, DisplayOrder = 2, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Ăn uống", Description = "Nhà hàng, quán ăn, bar, cafe trong tòa nhà", Icon = "🍽️", IsActive = true, DisplayOrder = 3, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Spa & Wellness", Description = "Spa, massage, phòng xông hơi, chăm sóc sức khỏe", Icon = "💆", IsActive = true, DisplayOrder = 4, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Hồ bơi", Description = "Hồ bơi trong nhà và ngoài trời", Icon = "🏊", IsActive = true, DisplayOrder = 5, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Khu vui chơi trẻ em", Description = "Khu vui chơi dành cho trẻ em", Icon = "🎠", IsActive = true, DisplayOrder = 6, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Phòng họp & Sự kiện", Description = "Phòng họp, sảnh sự kiện, phòng tiệc", Icon = "🎉", IsActive = true, DisplayOrder = 7, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Thư viện", Description = "Không gian đọc sách và học tập", Icon = "📚", IsActive = true, DisplayOrder = 8, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Karaoke", Description = "Phòng karaoke riêng", Icon = "🎤", IsActive = true, DisplayOrder = 9, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Sân tennis", Description = "Sân tennis trong nhà hoặc ngoài trời", Icon = "🎾", IsActive = true, DisplayOrder = 10, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Sân bóng rổ", Description = "Sân bóng rổ", Icon = "🏀", IsActive = true, DisplayOrder = 11, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Phòng gym", Description = "Phòng tập gym đầy đủ thiết bị", Icon = "💪", IsActive = true, DisplayOrder = 12, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Yoga & Pilates", Description = "Phòng yoga và pilates", Icon = "🧘", IsActive = true, DisplayOrder = 13, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "BBQ & Nướng", Description = "Khu vực BBQ và nướng ngoài trời", Icon = "🔥", IsActive = true, DisplayOrder = 14, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Khu vườn", Description = "Khu vườn, không gian xanh, vườn thượng", Icon = "🌳", IsActive = true, DisplayOrder = 15, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false },
        new { Id = Guid.NewGuid(), Name = "Khác", Description = "Các tiện ích khác", Icon = "📦", IsActive = true, DisplayOrder = 99, CreatedAtUtc = DateTime.UtcNow, IsDeleted = false }
    };

    foreach (var cat in categories)
    {
        migrationBuilder.InsertData(
            table: "Categories",
            columns: new[] { "Id", "Name", "Description", "Icon", "IsActive", "DisplayOrder", "CreatedAtUtc", "IsDeleted" },
            values: new object[] { cat.Id, cat.Name, cat.Description, cat.Icon, cat.IsActive, cat.DisplayOrder, cat.CreatedAtUtc, cat.IsDeleted });
    }

    // Đảm bảo cột Category trong Amenities tồn tại
    if (!migrationBuilder.HasColumn("Amenities", "Category"))
    {
        migrationBuilder.AddColumn<string>(
            name: "Category",
            table: "Amenities",
            type: "nvarchar(50)",
            maxLength: 50,
            nullable: true);
    }

    migrationBuilder.CreateIndex(
        name: "IX_Amenities_Category",
        table: "Amenities",
        column: "Category");
}
```

### Bước 3: Update Database

```powershell
dotnet ef database update
```

## Kiểm tra sau khi update

1. Kiểm tra bảng Categories đã được tạo:
```sql
SELECT * FROM Categories;
```

2. Kiểm tra có 16 categories:
```sql
SELECT COUNT(*) FROM Categories WHERE IsDeleted = 0;
```

3. Kiểm tra cột Category trong Amenities:
```sql
SELECT TOP 5 Id, Name, Category FROM Amenities;
```

## API Endpoints đã có

- `GET /api/Categories` - Lấy danh sách categories
- `GET /api/Categories/names` - Lấy chỉ tên categories (cho dropdown)
- `GET /api/Categories/{id}` - Lấy category theo ID
- `POST /api/Categories` - Tạo category mới (Admin)
- `PUT /api/Categories/{id}` - Cập nhật category (Admin)
- `DELETE /api/Categories/{id}` - Xóa category (Admin)
- `GET /api/Amenities?category=...` - Filter amenities theo category
- `GET /api/Amenities/categories` - Lấy categories từ Amenities hoặc Categories table

