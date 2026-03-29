# Stop API hiện tại
Write-Host "Stopping API..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*ICitizen*"} | Stop-Process -Force -ErrorAction SilentlyContinue

# Chờ 2 giây
Start-Sleep -Seconds 2

# Chạy lại API
Write-Host "`nStarting API..." -ForegroundColor Green
Write-Host "Location: d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen`n" -ForegroundColor Cyan

Set-Location "d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen"
dotnet run
