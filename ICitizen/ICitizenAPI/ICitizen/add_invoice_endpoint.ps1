$filePath = "d:\icitizen_app\ICitizen\ICitizenAPI\ICitizen\Controllers\InvoicesController.cs"
$content = Get-Content $filePath -Raw

# Code để insert
$newMethod = @"

    // POST /api/Invoices/{id}/payos-payment: Tạo PayOS payment link cho hóa đơn
    [HttpPost("{id}/payos-payment")]
    [Authorize]
    public async Task<IActionResult> CreatePayOsPayment(Guid id)
    {
        var inv = await _db.Invoices.FindAsync(id);
        if (inv is null) return NotFound();

        // Bảo mật: Cư dân chỉ tạo payment cho hóa đơn của căn hộ mình
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || inv.ApartmentId != profile.ApartmentId)
                return StatusCode(403, "Bạn không có quyền thanh toán hóa đơn này");
        }

        if (inv.TotalAmount <= 0)
            return BadRequest("Hóa đơn phải có số tiền > 0");

        try
        {
            var paymentResult = await _invoicePaymentService.EnsurePayOsPaymentAsync(inv, HttpContext);
            
            return Ok(new
            {
                paymentId = paymentResult.Payment.Id,
                checkoutUrl = paymentResult.Payment.CheckoutUrl,
                qrData = paymentResult.QrData
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi tạo PayOS payment cho hóa đơn {InvoiceId}", inv.Id);
            return StatusCode(500, "Không thể tạo liên kết thanh toán. Vui lòng thử lại.");
        }
    }
"@

# Tìm vị trí để insert (sau "return NoContent();" và trước "private static InvoiceResponseDto MapInvoice")
$pattern = "(\s+return NoContent\(\);\r\n\s+\})\r\n(\r\n\s+private static InvoiceResponseDto MapInvoice)"
$replacement = "`$1`r`n$newMethod`r`n`$2"

$newContent = $content -replace $pattern, $replacement

# Save lại file
$newContent | Set-Content $filePath -NoNewline

Write-Host "✅ Đã thêm endpoint CreatePayOsPayment vào InvoicesController.cs" -ForegroundColor Green
