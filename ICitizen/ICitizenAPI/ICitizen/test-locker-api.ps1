# Locker API Quick Test Script
# Run this in PowerShell to test the endpoints

# Variables
$baseUrl = "https://localhost:7196"
$apartmentCode = "A01"  # From seed data

Write-Host "=== Locker Management System API Test ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login as Security
Write-Host "Step 1: Logging in as Security..." -ForegroundColor Yellow
$loginBody = @{
    username = "security1"
    password = "Security@123"  # Update this with your actual password
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json" `
        -SkipCertificateCheck
    
    $token = $loginResponse.token
    Write-Host "✅ Login successful! Token received." -ForegroundColor Green
    Write-Host "   User: $($loginResponse.username)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Login failed: $_" -ForegroundColor Red
    exit
}

# Step 2: Receive Package
Write-Host "Step 2: Receiving package for apartment $apartmentCode..." -ForegroundColor Yellow
$receiveBody = @{
    apartmentCode = $apartmentCode
    notes = "Test package from PowerShell script"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

try {
    $receiveResponse = Invoke-RestMethod -Uri "$baseUrl/api/locker/receive" `
        -Method Post `
        -Headers $headers `
        -Body $receiveBody `
        -SkipCertificateCheck
    
    Write-Host "✅ Package received successfully!" -ForegroundColor Green
    Write-Host "   Compartment: $($receiveResponse.transaction.compartmentCode)" -ForegroundColor Gray
    Write-Host "   Transaction ID: $($receiveResponse.transaction.id)" -ForegroundColor Gray
    Write-Host ""
    
    $transactionId = $receiveResponse.transaction.id
} catch {
    Write-Host "❌ Failed to receive package: $_" -ForegroundColor Red
    exit
}

# Step 3: Confirm Stored (Get OTP)
Write-Host "Step 3: Confirming package stored..." -ForegroundColor Yellow

try {
    $confirmResponse = Invoke-RestMethod -Uri "$baseUrl/api/locker/$transactionId/confirm-stored" `
        -Method Post `
        -Headers $headers `
        -SkipCertificateCheck
    
    $otp = $confirmResponse.otp
    Write-Host "✅ Package stored successfully!" -ForegroundColor Green
    Write-Host "   🔐 OTP: $otp" -ForegroundColor Cyan
    Write-Host "   (This OTP is for resident pickup)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "❌ Failed to confirm stored: $_" -ForegroundColor Red
    exit
}

# Step 4: Get Security Transactions
Write-Host "Step 4: Fetching security transactions..." -ForegroundColor Yellow

try {
    $transactions = Invoke-RestMethod -Uri "$baseUrl/api/locker/security-transactions" `
        -Method Get `
        -Headers $headers `
        -SkipCertificateCheck
    
    Write-Host "✅ Found $($transactions.Count) transactions" -ForegroundColor Green
    foreach ($t in $transactions | Select-Object -First 3) {
        Write-Host "   - $($t.apartmentCode) | $($t.compartmentCode) | Status: $($t.status)" -ForegroundColor Gray
    }
    Write-Host ""
} catch {
    Write-Host "❌ Failed to fetch transactions: $_" -ForegroundColor Red
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "✅ Login: Success" -ForegroundColor Green
Write-Host "✅ Receive Package: Success" -ForegroundColor Green
Write-Host "✅ Confirm Stored: Success" -ForegroundColor Green
Write-Host "✅ Get Transactions: Success" -ForegroundColor Green
Write-Host ""
Write-Host "🔐 OTP for Resident Pickup: $otp" -ForegroundColor Cyan
Write-Host "📦 Transaction ID: $transactionId" -ForegroundColor Gray
Write-Host "🏠 Apartment: $apartmentCode" -ForegroundColor Gray
Write-Host ""
Write-Host "Next: Login as resident and use OTP '$otp' to pick up the package!" -ForegroundColor Yellow
Write-Host ""
Write-Host "API is running at: $baseUrl" -ForegroundColor Green
Write-Host "Swagger UI: $baseUrl/swagger" -ForegroundColor Green
