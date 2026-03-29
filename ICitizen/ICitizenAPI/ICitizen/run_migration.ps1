# Script PowerShell để chạy migration SQL trực tiếp vào database
# Connection string từ appsettings.json
$connectionString = "Server=localhost;Database=ICitizenDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"

# Đọc SQL script
$sqlScript = @"
IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[Invoices]') 
    AND name = 'Type'
)
BEGIN
    ALTER TABLE [dbo].[Invoices]
    ADD [Type] INT NOT NULL DEFAULT 0;
    
    PRINT 'Column Type added successfully to Invoices table';
END
ELSE
BEGIN
    PRINT 'Column Type already exists in Invoices table';
END
"@

Write-Host "Đang kết nối đến database..." -ForegroundColor Yellow
Write-Host "Connection: $connectionString" -ForegroundColor Gray

try {
    # Parse connection string để lấy thông tin
    $server = "localhost"
    $database = "ICitizenDb"
    
    # Chạy SQL script bằng sqlcmd
    $sqlcmdPath = "sqlcmd"
    
    # Kiểm tra xem sqlcmd có sẵn không
    $sqlcmdExists = Get-Command sqlcmd -ErrorAction SilentlyContinue
    
    if ($sqlcmdExists) {
        Write-Host "Đang chạy SQL script..." -ForegroundColor Yellow
        
        # Tạo file SQL tạm
        $tempSqlFile = [System.IO.Path]::GetTempFileName() + ".sql"
        $sqlScript | Out-File -FilePath $tempSqlFile -Encoding UTF8
        
        # Chạy sqlcmd
        $result = & sqlcmd -S $server -d $database -E -i $tempSqlFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Migration đã chạy thành công!" -ForegroundColor Green
            Write-Host $result
        } else {
            Write-Host "✗ Lỗi khi chạy migration" -ForegroundColor Red
            Write-Host $result
        }
        
        # Xóa file tạm
        Remove-Item $tempSqlFile -ErrorAction SilentlyContinue
    } else {
        Write-Host "sqlcmd không tìm thấy. Đang thử dùng .NET SQL Client..." -ForegroundColor Yellow
        
        # Sử dụng .NET SQL Client
        Add-Type -AssemblyName System.Data
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $command = New-Object System.Data.SqlClient.SqlCommand($sqlScript, $connection)
        
        try {
            $connection.Open()
            Write-Host "Đã kết nối đến database" -ForegroundColor Green
            
            $result = $command.ExecuteNonQuery()
            Write-Host "✓ Migration đã chạy thành công!" -ForegroundColor Green
            Write-Host "Rows affected: $result" -ForegroundColor Gray
        }
        catch {
            Write-Host "✗ Lỗi: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            if ($connection.State -eq 'Open') {
                $connection.Close()
            }
        }
    }
}
catch {
    Write-Host "✗ Lỗi: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Gray
}

Write-Host "`nHoàn tất!" -ForegroundColor Cyan























