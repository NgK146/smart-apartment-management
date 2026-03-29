# Script test API Suggestions
# Sử dụng: .\test_suggestions.ps1

$baseUrl = "http://localhost:5000"
$httpsUrl = "https://localhost:7000"

# Thử HTTP trước, nếu lỗi thì thử HTTPS
try {
    $testUrl = $baseUrl
    Write-Host "Đang test với: $testUrl" -ForegroundColor Yellow
    $null = Invoke-WebRequest -Uri "$testUrl/api/Suggestions/test/residents" -Method Get -TimeoutSec 5
} catch {
    Write-Host "HTTP không khả dụng, thử HTTPS..." -ForegroundColor Yellow
    $testUrl = $httpsUrl
}

Write-Host "`n=== Lấy danh sách Residents ===" -ForegroundColor Green
try {
    $residentsResponse = Invoke-RestMethod -Uri "$testUrl/api/Suggestions/test/residents" -Method Get
    Write-Host "✓ Tìm thấy $($residentsResponse.count) residents" -ForegroundColor Green
    
    if ($residentsResponse.residents.Count -eq 0) {
        Write-Host "⚠ Không có residents nào. Vui lòng tạo ResidentProfile trước." -ForegroundColor Red
        exit
    }
    
    Write-Host "`nDanh sách Residents:" -ForegroundColor Cyan
    $residentsResponse.residents | Format-Table id, apartmentCode, building, floor, age, lifeStyle
    
    # Test với resident đầu tiên
    $residentId = $residentsResponse.residents[0].id
    Write-Host "`n=== Test gợi ý cho Resident: $residentId ===" -ForegroundColor Green
    Write-Host "Apartment: $($residentsResponse.residents[0].apartmentCode)" -ForegroundColor Cyan
    Write-Host "Building: $($residentsResponse.residents[0].building)" -ForegroundColor Cyan
    Write-Host "Floor: $($residentsResponse.residents[0].floor)" -ForegroundColor Cyan
    
    $suggestionsResponse = Invoke-RestMethod -Uri "$testUrl/api/Suggestions/test/$residentId" -Method Get
    
    Write-Host "`n✓ Resident Info:" -ForegroundColor Green
    $suggestionsResponse.resident | Format-List
    
    Write-Host "`n=== Top 10 Suggestions (theo điểm số) ===" -ForegroundColor Green
    $top10 = $suggestionsResponse.suggestions | Select-Object -First 10
    $top10 | Format-Table -AutoSize code, @{Label="Title"; Expression={$_.title.Substring(0, [Math]::Min(40, $_.title.Length))}}, score, tags
    
    Write-Host "`n=== Summary ===" -ForegroundColor Green
    Write-Host "Total suggestions: $($suggestionsResponse.summary.total)" -ForegroundColor Cyan
    Write-Host "Top score: $($suggestionsResponse.summary.topScore)" -ForegroundColor Cyan
    Write-Host "Average score: $([math]::Round($suggestionsResponse.summary.averageScore, 2))" -ForegroundColor Cyan
    
    Write-Host "`n=== Phân tích ===" -ForegroundColor Green
    $highScore = $suggestionsResponse.suggestions | Where-Object { $_.score -ge 50 }
    Write-Host "Hoạt động có điểm cao (≥50): $($highScore.Count)" -ForegroundColor Yellow
    if ($highScore.Count -gt 0) {
        $highScore | Select-Object -First 5 | Format-Table code, title, score
    }
    
    $lowScore = $suggestionsResponse.suggestions | Where-Object { $_.score -lt 0 }
    if ($lowScore.Count -gt 0) {
        Write-Host "`nHoạt động có điểm âm (không phù hợp): $($lowScore.Count)" -ForegroundColor Red
        $lowScore | Select-Object -First 3 | Format-Table code, title, score
    }
    
} catch {
    Write-Host "`n❌ Lỗi: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Đảm bảo API đang chạy tại: $testUrl" -ForegroundColor Yellow
    Write-Host "Chạy: cd ICitizen/ICitizenAPI/ICitizen; dotnet run" -ForegroundColor Yellow
}

