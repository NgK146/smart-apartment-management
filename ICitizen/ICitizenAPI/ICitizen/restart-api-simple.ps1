# Hướng Dẫn Restart API - Đơn Giản

Write-Host "=== RESTART API ===" -ForegroundColor Cyan
Write-Host ""

# Bước 1: Dừng API hiện tại
Write-Host "Bước 1: Dừng API đang chạy..." -ForegroundColor Yellow
$processes = Get-Process | Where-Object {$_.ProcessName -like "*ICitizen*" -or $_.ProcessName -like "*dotnet*"}
if ($processes) {
    $processes | Stop-Process -Force
    Write-Host "✓ Đã dừng API" -ForegroundColor Green
} else {
    Write-Host "! Không tìm thấy API đang chạy" -ForegroundColor Gray
}

Start-Sleep -Seconds 2

# Bước 2: Chạy lại API
Write-Host ""
Write-Host "Bước 2: Khởi động API..." -ForegroundColor Yellow
Set-Location "d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen"

Write-Host ""
Write-Host "API đang khởi động... Đợi cho đến khi thấy 'Application started'" -ForegroundColor Cyan
Write-Host "Để dừng API, nhấn Ctrl+C" -ForegroundColor Gray
Write-Host ""

dotnet run
