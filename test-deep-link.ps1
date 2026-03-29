# Test Deep Link for Payment Success
# Trigger deep link manually to test if Flutter app handles correctly

Write-Host "🧪 Testing Deep Link: icitizen://payment/success" -ForegroundColor Cyan

# Find adb path
$adbPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "C:\Android\sdk\platform-tools\adb.exe"
)

$adb = $null
foreach ($path in $adbPaths) {
    if (Test-Path $path) {
        $adb = $path
        Write-Host "✓ Found ADB: $path" -ForegroundColor Green
        break
    }
}

if (-not $adb) {
    Write-Host "❌ ADB not found! Please install Android SDK or add ADB to PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Bạn có thể test manual bằng cách:" -ForegroundColor Yellow
    Write-Host "1. Mở Terminal trong Android Studio" -ForegroundColor Yellow
    Write-Host "2. Run lệnh này:" -ForegroundColor Yellow
    Write-Host '   adb shell am start -W -a android.intent.action.VIEW -d "icitizen://payment/success?orderCode=TEST123&invoiceId=5cc36e91-b1f1-4542-908d-4e982d262a14" com.example.icitizen_app' -ForegroundColor Cyan
    exit 1
}

# Test deep link
Write-Host ""
Write-Host "📱 Sending deep link to device..." -ForegroundColor Yellow

$invoiceId = "5cc36e91-b1f1-4542-908d-4e982d262a14"
$orderCode = "TEST12345"
$deepLink = "icitizen://payment/success?orderCode=$orderCode&invoiceId=$invoiceId"

Write-Host "URL: $deepLink" -ForegroundColor Gray

& $adb shell am start -W -a android.intent.action.VIEW -d $deepLink com.example.icitizen_app

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deep link sent successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔍 Check Flutter app:" -ForegroundColor Cyan
    Write-Host "  1. App should switch to 'Hóa đơn' tab" -ForegroundColor White
    Write-Host "  2. Toast shows: '✅ Thanh toán thành công! Mã: $orderCode'" -ForegroundColor White
    Write-Host "  3. Invoice detail auto-opens" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Check Flutter logs for:" -ForegroundColor Cyan
    Write-Host '  "🔗 Deep link received: icitizen://payment/success..."' -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Failed to send deep link" -ForegroundColor Red
    Write-Host "Error code: $LASTEXITCODE" -ForegroundColor Red
}
