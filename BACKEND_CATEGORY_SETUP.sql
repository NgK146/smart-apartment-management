-- ============================================
-- Script SQL để tạo bảng Categories và insert dữ liệu
-- ============================================

-- Tạo bảng Categories
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Categories]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Categories] (
        [Id] INT PRIMARY KEY IDENTITY(1,1),
        [Name] NVARCHAR(100) NOT NULL UNIQUE,
        [Description] NVARCHAR(500) NULL,
        [Icon] NVARCHAR(50) NULL,
        [IsActive] BIT NOT NULL DEFAULT 1,
        [DisplayOrder] INT NOT NULL DEFAULT 0,
        [CreatedAt] DATETIME NOT NULL DEFAULT GETDATE(),
        [UpdatedAt] DATETIME NOT NULL DEFAULT GETDATE()
    );
    
    CREATE INDEX IX_Categories_IsActive ON [dbo].[Categories]([IsActive]);
    CREATE INDEX IX_Categories_DisplayOrder ON [dbo].[Categories]([DisplayOrder]);
    
    PRINT 'Bảng Categories đã được tạo thành công.';
END
ELSE
BEGIN
    PRINT 'Bảng Categories đã tồn tại.';
END
GO

-- Insert categories mặc định cho chung cư cao cấp
-- Chỉ insert nếu chưa có dữ liệu
IF NOT EXISTS (SELECT 1 FROM [dbo].[Categories])
BEGIN
    INSERT INTO [dbo].[Categories] ([Name], [Description], [Icon], [DisplayOrder]) VALUES
    ('Thể thao & Fitness', 'Các tiện ích thể thao và fitness như phòng gym, sân tennis, bóng rổ', '🏋️', 1),
    ('Giải trí', 'Khu vực giải trí và vui chơi như karaoke, game room', '🎮', 2),
    ('Ăn uống', 'Nhà hàng, quán ăn, bar, cafe trong tòa nhà', '🍽️', 3),
    ('Spa & Wellness', 'Spa, massage, phòng xông hơi, chăm sóc sức khỏe', '💆', 4),
    ('Hồ bơi', 'Hồ bơi trong nhà và ngoài trời', '🏊', 5),
    ('Khu vui chơi trẻ em', 'Khu vui chơi dành cho trẻ em', '🎠', 6),
    ('Phòng họp & Sự kiện', 'Phòng họp, sảnh sự kiện, phòng tiệc', '🎉', 7),
    ('Thư viện', 'Không gian đọc sách và học tập', '📚', 8),
    ('Karaoke', 'Phòng karaoke riêng', '🎤', 9),
    ('Sân tennis', 'Sân tennis trong nhà hoặc ngoài trời', '🎾', 10),
    ('Sân bóng rổ', 'Sân bóng rổ', '🏀', 11),
    ('Phòng gym', 'Phòng tập gym đầy đủ thiết bị', '💪', 12),
    ('Yoga & Pilates', 'Phòng yoga và pilates', '🧘', 13),
    ('BBQ & Nướng', 'Khu vực BBQ và nướng ngoài trời', '🔥', 14),
    ('Khu vườn', 'Khu vườn, không gian xanh, vườn thượng', '🌳', 15),
    ('Khác', 'Các tiện ích khác', '📦', 99);
    
    PRINT 'Đã insert ' + CAST(@@ROWCOUNT AS NVARCHAR(10)) + ' categories mặc định.';
END
ELSE
BEGIN
    PRINT 'Categories đã có dữ liệu, bỏ qua insert.';
END
GO

-- Đảm bảo bảng Amenities có cột Category
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Amenities]') AND name = 'Category')
BEGIN
    ALTER TABLE [dbo].[Amenities]
    ADD [Category] NVARCHAR(100) NULL;
    
    -- Tạo index cho Category để tìm kiếm nhanh hơn
    CREATE INDEX IX_Amenities_Category ON [dbo].[Amenities]([Category]);
    
    PRINT 'Đã thêm cột Category vào bảng Amenities.';
END
ELSE
BEGIN
    PRINT 'Cột Category đã tồn tại trong bảng Amenities.';
END
GO

-- Tạo foreign key relationship (optional - nếu muốn đảm bảo tính toàn vẹn dữ liệu)
-- ALTER TABLE [dbo].[Amenities]
-- ADD CONSTRAINT FK_Amenities_Category 
-- FOREIGN KEY ([Category]) REFERENCES [dbo].[Categories]([Name]);
-- GO

PRINT 'Hoàn tất setup Categories!';
GO

