# Test Login API
$uri = "https://untippled-anyway-al.ngrok-free.dev/api/Auth/login"

$body = @{
    username = "hokhoi1"
    password = "Khoi123@"
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}

Write-Host "Testing login API for hokhoi1..." -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers

Write-Host "`nResponse:" -ForegroundColor Green
$response | ConvertTo-Json -Depth 5

Write-Host "`nRoles:" -ForegroundColor Cyan
$response.roles

if ($response.roles -and $response.roles.Count -gt 0) {
    Write-Host "`n[SUCCESS] User has roles!" -ForegroundColor Green
    Write-Host "Roles: $($response.roles -join ', ')" -ForegroundColor Green
} else {
    Write-Host "`n[FAIL] Roles array is EMPTY!" -ForegroundColor Red
    Write-Host "Backend is NOT returning roles." -ForegroundColor Red
}
