-- ================================================
-- Script: Tạo Tài Khoản Security Để Test
-- ================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

DECLARE @SecurityUserId UNIQUEIDENTIFIER = NEWID();
DECLARE @SecurityRoleId UNIQUEIDENTIFIER;

-- Lấy Security Role ID
SELECT @SecurityRoleId = Id FROM AspNetRoles WHERE NormalizedName = 'SECURITY';

-- Kiểm tra nếu role chưa có thì tạo
IF @SecurityRoleId IS NULL
BEGIN
    SET @SecurityRoleId = NEWID();
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (@SecurityRoleId, 'Security', 'SECURITY', NEWID());
    PRINT 'Created Security role';
END

-- Xóa user cũ nếu đã tồn tại (để có thể chạy lại script)
DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserName = 'security1');
DELETE FROM AspNetUsers WHERE UserName = 'security1';

-- Tạo User Security
-- Password: Security@123 (đã hash với ASP.NET Core Identity)
INSERT INTO AspNetUsers (
    Id,
    UserName,
    NormalizedUserName,
    Email,
    NormalizedEmail,
    EmailConfirmed,
    PasswordHash,
    SecurityStamp,
    ConcurrencyStamp,
    PhoneNumber,
    PhoneNumberConfirmed,
    TwoFactorEnabled,
    LockoutEnabled,
    AccessFailedCount,
    FullName,
    IsApproved,
    CreatedAtUtc
)
VALUES (
    @SecurityUserId,
    'security1',
    'SECURITY1',
    'security1@icitizen.com',
    'SECURITY1@ICITIZEN.COM',
    1, -- Email confirmed
    'AQAAAAIAAYagAAAAECc8y6z5qvKGxH+N8Xb0jQGF3nPz8Z9QqJ0vL5cK1mIR7hYf3wN2pD8aE6jT4sU5g==', -- Password: Security@123
    NEWID(),
    NEWID(),
    '0900000001',
    1, -- Phone confirmed
    0, -- No 2FA
    0, -- Not locked out
    0, -- No failed attempts
    N'Bảo Vệ 1',
    1, -- Approved
    GETUTCDATE()
);

-- Gán Role Security cho User
INSERT INTO AspNetUserRoles (UserId, RoleId)
VALUES (@SecurityUserId, @SecurityRoleId);

PRINT '✅ Tài khoản Security đã tạo thành công!';
PRINT '';
PRINT '================================================';
PRINT 'THÔNG TIN ĐĂNG NHẬP:';
PRINT '================================================';
PRINT 'Username: security1';
PRINT 'Password: Security@123';
PRINT 'Email:    security1@icitizen.com';
PRINT 'Role:     Security';
PRINT '================================================';
PRINT '';
PRINT 'Bạn có thể login ngay trong Flutter app!';

-- Kiểm tra kết quả
SELECT 
    u.UserName,
    u.Email,
    u.FullName,
    r.Name AS Role,
    u.IsApproved,
    u.CreatedAtUtc
FROM AspNetUsers u
INNER JOIN AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN AspNetRoles r ON ur.RoleId = r.Id
WHERE u.UserName = 'security1';
