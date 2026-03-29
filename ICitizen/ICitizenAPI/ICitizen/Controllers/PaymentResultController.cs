using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ICitizen.Data;
using Microsoft.EntityFrameworkCore;
using ICitizen.Domain;
using ICitizen.Services;

namespace ICitizen.Controllers;

[ApiController]
[Route("payment")]
[AllowAnonymous]
public class PaymentResultController : ControllerBase
{
    private readonly ILogger<PaymentResultController> _logger;
    private readonly ApplicationDbContext _db;
    private readonly PaymentBlockchainService _blockchain;

    public PaymentResultController(
        ILogger<PaymentResultController> logger,
        ApplicationDbContext db,
        PaymentBlockchainService blockchain)
    {
        _logger = logger;
        _db = db;
        _blockchain = blockchain;
    }

    [HttpGet("payos-result")]
    public async Task<IActionResult> PayOsResult([FromQuery] string? orderCode, [FromQuery] string? status, [FromQuery] string? invoiceId)
    {
        _logger.LogInformation("PayOS result called: orderCode={OrderCode}, status={Status}, invoiceId={InvoiceId}", 
            orderCode, status, invoiceId);
        
        bool isSuccess = status?.ToLower() == "paid" || status?.ToLower() == "success";
        
        // Nếu thanh toán thành công, cập nhật invoice và payment status
        if (isSuccess && !string.IsNullOrWhiteSpace(orderCode))
        {
            try
            {
                // Tìm payment theo orderCode (bắt buộc vì PayOS overwrite query params)
                var payment = await _db.Payments
                    .Include(p => p.Invoice)
                    .FirstOrDefaultAsync(p => p.TransactionCode == orderCode || p.TransactionRef == orderCode);
                
                if (payment != null)
                {
                    // Update payment status
                    payment.Status = PaymentStatus.Success;
                    payment.PaidAtUtc = DateTime.UtcNow;
                    payment.TransactionRef = orderCode;
                    
                    // Update invoice status if exists
                    if (payment.Invoice != null)
                    {
                        payment.Invoice.Status = InvoiceStatus.Paid;
                        payment.Invoice.UpdatedAtUtc = DateTime.UtcNow;
                        _logger.LogInformation("✅ Updated invoice {InvoiceId} status to Paid", payment.Invoice.Id);
                        
                        // Ghi lên blockchain để minh bạch
                        try
                        {
                            var txHash = await _blockchain.RecordPaymentAsync(
                                invoiceId: payment.Invoice.Id.ToString(),
                                apartmentId: payment.Invoice.ApartmentId.ToString(),
                                amountVND: payment.Amount,
                                paymentMethod: "PayOS",
                                status: "SUCCESS"
                            );
                            
                            // Lưu blockchain hash vào payment
                            payment.BlockchainTxHash = txHash;
                            _logger.LogInformation("🔗 Blockchain recorded: {TxHash}", txHash);
                        }
                        catch (Exception bcEx)
                        {
                            _logger.LogError(bcEx, "Blockchain recording failed - payment still successful");
                            // Không throw - thanh toán vẫn OK!
                        }
                    }
                    
                    await _db.SaveChangesAsync();
                    _logger.LogInformation("✅ Updated payment {PaymentId} status to Success", payment.Id);
                }
                else
                {
                    _logger.LogWarning("⚠️ Payment not found for orderCode: {OrderCode}", orderCode);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Error updating payment/invoice status for orderCode: {OrderCode}", orderCode);
            }
        }
        
        string title = isSuccess ? "Thanh toán thành công!" : "Thanh toán thất bại";
        string icon = isSuccess ? "✅" : "❌";
        string message = isSuccess 
            ? "Giao dịch của bạn đã được xử lý thành công." 
            : "Giao dịch không thành công. Vui lòng thử lại.";
        string buttonColor = isSuccess ? "#4CAF50" : "#f44336";
        
        var html = $@"
<!DOCTYPE html>
<html lang='vi'>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>{title}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        
        .container {{
            background: white;
            border-radius: 20px;
            padding: 40px 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 400px;
            width: 100%;
            animation: slideUp 0.5s ease-out;
        }}
        
        @keyframes slideUp {{
            from {{
                opacity: 0;
                transform: translateY(30px);
            }}
            to {{
                opacity: 1;
                transform: translateY(0);
            }}
        }}
        
        .icon {{
            font-size: 72px;
            margin-bottom: 20px;
            animation: bounce 0.6s ease-in-out;
        }}
        
        @keyframes bounce {{
            0%, 100% {{ transform: scale(1); }}
            50% {{ transform: scale(1.1); }}
        }}
        
        h1 {{
            color: #333;
            font-size: 24px;
            margin-bottom: 10px;
            font-weight: 600;
        }}
        
        .message {{
            color: #666;
            font-size: 16px;
            margin-bottom: 10px;
            line-height: 1.5;
        }}
        
        .order-code {{
            background: #f5f5f5;
            border-radius: 10px;
            padding: 15px;
            margin: 20px 0;
            font-size: 14px;
            color: #555;
        }}
        
        .order-code strong {{
            color: #333;
            display: block;
            margin-bottom: 5px;
        }}
        
        button {{
            background: {buttonColor};
            color: white;
            border: none;
            border-radius: 12px;
            padding: 16px 40px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }}
        
        button:hover {{
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0,0,0,0.3);
        }}
        
        button:active {{
            transform: translateY(0);
        }}
        
        .footer {{
            margin-top: 20px;
            font-size: 12px;
            color: #999;
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='icon'>{icon}</div>
        <h1>{title}</h1>
        <p class='message'>{message}</p>
        <div class='order-code'>
            <strong>Mã giao dịch</strong>
            {orderCode ?? "N/A"}
        </div>
        <button onclick='closePayment()'>Quay lại trang hóa đơn</button>
        <p class='footer'>Cảm ơn bạn đã sử dụng dịch vụ</p>
    </div>
    
    <script>
        function closePayment() {{
            // Send close message to Flutter
            if (window.DeepLinkChannel) {{
                DeepLinkChannel.postMessage('close');
            }}
            // Fallback: try to close window
            window.close();
        }}
    </script>
</body>
</html>";
        
        return Content(html, "text/html");
    }

    [HttpGet("payos-cancel")]
    public IActionResult PayOsCancel([FromQuery] string? orderCode, [FromQuery] string? invoiceId)
    {
        _logger.LogInformation("PayOS cancel called: orderCode={OrderCode}, invoiceId={InvoiceId}", orderCode, invoiceId);
        
        var html = $@"
<!DOCTYPE html>
<html lang='vi'>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Đã hủy thanh toán</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        
        .container {{
            background: white;
            border-radius: 20px;
            padding: 40px 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 400px;
            width: 100%;
        }}
        
        .icon {{ font-size: 72px; margin-bottom: 20px; }}
        h1 {{ color: #333; font-size: 24px; margin-bottom: 10px; }}
        .message {{ color: #666; font-size: 16px; margin-bottom: 20px; }}
        
        button {{
            background: #FF9800;
            color: white;
            border: none;
            border-radius: 12px;
            padding: 16px 40px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='icon'>⚠️</div>
        <h1>Đã hủy thanh toán</h1>
        <p class='message'>Giao dịch đã bị hủy bởi người dùng.</p>
        <button onclick='closePayment()'>Quay lại</button>
    </div>
    
    <script>
        function closePayment() {{
            if (window.DeepLinkChannel) {{
                DeepLinkChannel.postMessage('close');
            }}
            window.close();
        }}
    </script>
</body>
</html>";
        
        return Content(html, "text/html");
    }
}
