# Script PowerShell: Tạo Tài Khoản Security Qua API

$baseUrl = "https://localhost:7196"

Write-Host "=== Tạo Tài Khoản Security ===" -ForegroundColor Cyan
Write-Host ""

# Xóa user cũ nếu có (optional - để chạy lại script)
Write-Host "Step 1: Xóa user security1 cũ (nếu có)..." -ForegroundColor Yellow

try {
    $deleteBody = @'
DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserName = 'security1');
DELETE FROM AspNetUsers WHERE UserName = 'security1';
'@
    
    # Chạy bằng sqlcmd (comment out nếu không muốn xóa)
    # sqlcmd -S localhost -d ICitizenDb -E -Q $deleteBody
    Write-Host "   (Bỏ qua xóa user cũ)" -ForegroundColor Gray
} catch {
    Write-Host "   Không có user cũ hoặc lỗi: $_" -ForegroundColor Gray
}

Write-Host ""

# Step 2: Đăng ký tài khoản Security qua API
Write-Host "Step 2: Đăng ký tài khoản security1 qua API..." -ForegroundColor Yellow

$registerBody = @{
    username = "security1"
    password = "Security@123"
    fullName = "Bảo Vệ 1"
    email = "security1@icitizen.com"
    phoneNumber = "0900000001"
    desiredRole = "Security"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" `
        -Method Post `
        -Body $registerBody `
        -ContentType "application/json" `
        -SkipCertificateCheck
    
    Write-Host "   ✅ Đăng ký thành công!" -ForegroundColor Green
    Write-Host "   Response: $registerResponse" -ForegroundColor Gray
} catch {
    $errorDetail = $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorDetail = $reader.ReadToEnd()
    }
    Write-Host "   ⚠️  Lỗi đăng ký: $errorDetail" -ForegroundColor Yellow
    Write-Host "   (Có thể user đã tồn tại - tiếp tục test login)" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Approve user (vì đăng ký mặc định IsApproved = false)
Write-Host "Step 3: Approve user security1 trong database..." -ForegroundColor Yellow

$approveQuery = @"
UPDATE AspNetUsers 
SET IsApproved = 1 
WHERE UserName = 'security1';

SELECT UserName, IsApproved FROM AspNetUsers WHERE UserName = 'security1';
"@

try {
    sqlcmd -S localhost -d ICitizenDb -E -Q $approveQuery | Out-String | Write-Host -ForegroundColor Gray
    Write-Host "   ✅ User đã được approve!" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Lỗi approve: $_" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Gán role Security (nếu chưa có)
Write-Host "Step 4: Gán role Security..." -ForegroundColor Yellow

$assignRoleQuery = @"
SET QUOTED_IDENTIFIER ON;

DECLARE @UserId UNIQUEIDENTIFIER = (SELECT Id FROM AspNetUsers WHERE UserName = 'security1');
DECLARE @RoleId UNIQUEIDENTIFIER = (SELECT Id FROM AspNetRoles WHERE NormalizedName = 'SECURITY');

-- Tạo role nếu chưa có
IF @RoleId IS NULL
BEGIN
    SET @RoleId = NEWID();
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (@RoleId, 'Security', 'SECURITY', NEWID());
END

-- Xóa role cũ (nếu có)
DELETE FROM AspNetUserRoles WHERE UserId = @UserId;

-- Gán role Security
INSERT INTO AspNetUserRoles (UserId, RoleId)
VALUES (@UserId, @RoleId);

-- Kiểm tra
SELECT u.UserName, r.Name AS Role, u.IsApproved
FROM AspNetUsers u
INNER JOIN AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN AspNetRoles r ON ur.RoleId = r.Id
WHERE u.UserName = 'security1';
"@

try {
    sqlcmd -S localhost -d ICitizenDb -E -Q $assignRoleQuery | Out-String | Write-Host -ForegroundColor Gray
    Write-Host "   ✅ Role Security đã được gán!" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Lỗi gán role: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Step 5: Test Login
Write-Host "Step 5: Test Login..." -ForegroundColor Yellow

$loginBody = @{
    username = "security1"
    password = "Security@123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json" `
        -SkipCertificateCheck
    
    Write-Host "   ✅ ✅ ✅ LOGIN THÀNH CÔNG! ✅ ✅ ✅" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Username: $($loginResponse.username)" -ForegroundColor Cyan
    Write-Host "   Full Name: $($loginResponse.fullName)" -ForegroundColor Cyan
    Write-Host "   Roles: $($loginResponse.roles -join ', ')" -ForegroundColor Cyan
    Write-Host "   Token: $($loginResponse.accessToken.Substring(0, 50))..." -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "   ❌ LOGIN THẤT BẠI!" -ForegroundColor Red
    $errorDetail = $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorDetail = $reader.ReadToEnd()
    }
    Write-Host "   Error: $errorDetail" -ForegroundColor Red
    Write-Host ""
}

Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "THÔNG TIN ĐĂNG NHẬP:" -ForegroundColor Yellow
Write-Host "Username: security1" -ForegroundColor White
Write-Host "Password: Security@123" -ForegroundColor White
Write-Host ""
Write-Host "Bây giờ có thể login trong Flutter app!" -ForegroundColor Green
