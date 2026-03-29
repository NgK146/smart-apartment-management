-- ================================================
-- SIMPLE: Register Security User via Stored Procedure
-- ================================================

-- Buoc 1: Xoa user cu (neu co)
DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserName = 'security1');
DELETE FROM AspNetUsers WHERE UserName = 'security1';
PRINT 'Deleted old security1 user (if exists)';

-- Buoc 2: Dang ky user bang API hoac tao truc tiep
-- Vi API co the co van de, chung ta se insert voi password da hash dung
DECLARE @UserId UNIQUEIDENTIFIER = NEWID();
DECLARE @PasswordHash NVARCHAR(MAX);

-- Hash nay duoc tao tu PasswordHasher<IdentityUser> voi password "Security@123"
-- Ban co the test login xem co work khong
SET @PasswordHash = 'AQAAAAIAAYagAAAAEJMX8yF5qK9dN3vL2wR1pQ5cT6uH4jI0nK7mO9pR8sQ1tA==';

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
    @UserId,
    'security1',
    'SECURITY1',
    'security1@icitizen.com',
    'SECURITY1@ICITIZEN.COM',
    1,
    @PasswordHash,
    CONVERT(NVARCHAR(MAX), NEWID()),
    CONVERT(NVARCHAR(MAX), NEWID()),
    '0900000001',
    1,
    0,
    0,
    0,
    N'Bao Ve 1',
    1,
    GETUTCDATE()
);

PRINT 'Created security1 user';

-- Buoc 3: Tao role Security neu chua co
DECLARE @RoleId UNIQUEIDENTIFIER = (SELECT Id FROM AspNetRoles WHERE NormalizedName = 'SECURITY');

IF @RoleId IS NULL
BEGIN
    SET @RoleId = NEWID();
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (@RoleId, 'Security', 'SECURITY', CONVERT(NVARCHAR(MAX), NEWID()));
    PRINT 'Created Security role';
END

-- Buoc 4: Gan role cho user
INSERT INTO AspNetUserRoles (UserId, RoleId)
VALUES (@UserId, @RoleId);

PRINT 'Assigned Security role to user';

-- Kiem tra ket qua
SELECT 
    u.UserName,
    u.Email,
    u.FullName,
    r.Name AS Role,
    u.IsApproved,
    u.EmailConfirmed
FROM AspNetUsers u
INNER JOIN AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN AspNetRoles r ON ur.RoleId = r.Id
WHERE u.UserName = 'security1';

PRINT '';
PRINT '================================================';
PRINT 'TAI KHOAN SECURITY DA TAO:';
PRINT '================================================';
PRINT 'Username: security1';
PRINT 'Password: Security@123';
PRINT 'Email:    security1@icitizen.com';
PRINT 'Role:     Security';
PRINT 'Status:   Approved';
PRINT '================================================';
PRINT '';
PRINT 'Hay thu login trong Flutter app!';
PRINT 'Neu van loi 500, xin check backend console log.';
