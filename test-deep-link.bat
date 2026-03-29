@echo off
REM Test Deep Link Script
echo Testing Deep Link: icitizen://payment/success
echo.

REM Find adb
set ADB_PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

if not exist "%ADB_PATH%" (
    echo ADB not found!
    echo.
    echo Manual test: Open Android Studio Terminal and run:
    echo adb shell am start -W -a android.intent.action.VIEW -d "icitizen://payment/success?orderCode=TEST123&invoiceId=5cc36e91-b1f1-4542-908d-4e982d262a14" com.example.icitizen_app
    pause
    exit /b 1
)

echo ADB found: %ADB_PATH%
echo.
echo Sending deep link to device...

"%ADB_PATH%" shell am start -W -a android.intent.action.VIEW -d "icitizen://payment/success?orderCode=TEST123&invoiceId=5cc36e91-b1f1-4542-908d-4e982d262a14" com.example.icitizen_app

echo.
echo Done! Check Flutter app:
echo - Should switch to Hoa don tab
echo - Toast shows: "Thanh toan thanh cong! Ma: TEST123"
echo - Invoice detail auto-opens
echo.
echo Check Flutter logs for: "Deep link received: icitizen://payment/success..."
pause
