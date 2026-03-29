-- ================================================
-- FIX: Gán Resident role cho hokhoi1
-- ================================================

DECLARE @UserId UNIQUEIDENTIFIER = (SELECT Id FROM AspNetUsers WHERE UserName = 'hokhoi1');
DECLARE @RoleId UNIQUEIDENTIFIER;

-- Tìm hoặc tạo Resident role
SET @RoleId = (SELECT Id FROM AspNetRoles WHERE NormalizedName = 'RESIDENT');

IF @RoleId IS NULL
BEGIN
    SET @RoleId = NEWID();
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (@RoleId, 'Resident', 'RESIDENT', NEWID());
    PRINT '✓ Created Resident role';
END

-- Xóa roles cũ
DELETE FROM AspNetUserRoles WHERE UserId = @UserId;

-- Thêm Resident role
INSERT INTO AspNetUserRoles (UserId, RoleId)
VALUES (@UserId, @RoleId);

PRINT '✓ Assigned Resident role to hokhoi1';

-- Kiểm tra kết quả
SELECT 
    u.UserName,
    u.Email,
    r.Name AS Role,
    u.ApartmentCode,
    u.IsApproved
FROM AspNetUsers u
LEFT JOIN AspNetUserRoles ur ON u.Id = ur.UserId
LEFT JOIN AspNetRoles r ON ur.RoleId = r.Id
WHERE u.UserName = 'hokhoi1';

PRINT '';
PRINT '================================================';
PRINT 'User hokhoi1 now has Resident role!';
PRINT 'Please RE-LOGIN in Flutter app to get new token';
PRINT '================================================';
