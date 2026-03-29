using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ICitizen.Migrations
{
    /// <inheritdoc />
    public partial class AddCategoriesTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Thêm ErrorCode vào Payments nếu chưa có
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Payments]') AND name = 'ErrorCode')
                BEGIN
                    ALTER TABLE [dbo].[Payments] ADD [ErrorCode] nvarchar(10) NULL;
                END
            ");

            // Thêm ErrorMessage vào Payments nếu chưa có
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Payments]') AND name = 'ErrorMessage')
                BEGIN
                    ALTER TABLE [dbo].[Payments] ADD [ErrorMessage] nvarchar(500) NULL;
                END
            ");

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
                name: "IX_Categories_IsActive_DisplayOrder",
                table: "Categories",
                columns: new[] { "IsActive", "DisplayOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_Categories_Name",
                table: "Categories",
                column: "Name",
                unique: true);

            // Thêm cột Category vào Amenities nếu chưa có (sẽ không lỗi nếu đã tồn tại)
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Amenities]') AND name = 'Category')
                BEGIN
                    ALTER TABLE [dbo].[Amenities] ADD [Category] nvarchar(50) NULL;
                END
            ");

            // Tạo index cho Category trong Amenities (sẽ không lỗi nếu đã tồn tại)
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Amenities_Category' AND object_id = OBJECT_ID(N'[dbo].[Amenities]'))
                BEGIN
                    CREATE INDEX [IX_Amenities_Category] ON [dbo].[Amenities] ([Category]);
                END
            ");

            // Insert seed data cho categories
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Categories");

            migrationBuilder.DropColumn(
                name: "ErrorCode",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "ErrorMessage",
                table: "Payments");
        }
    }
}
