using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PayOS;
using PayOS.Models.V2.PaymentRequests;
using PayOS.Models.Webhooks;
using System.Globalization;
using System.Text;
using System.Collections.Generic;
using System.Net.Http;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly IVnPayService _vnPay;
    private readonly PayOSClient _payOs;
    private readonly IConfiguration _config;
    private readonly ILogger<PaymentsController> _logger;
    private readonly IPaymentNotificationService _paymentNotificationService;
    private readonly PaymentBlockchainService _blockchain;

    public PaymentsController(
        ApplicationDbContext db, 
        IVnPayService vnPay, 
        IConfiguration configuration, 
        ILogger<PaymentsController> logger,
        IPaymentNotificationService paymentNotificationService,
        PaymentBlockchainService blockchain)
    {
        _db = db;
        _vnPay = vnPay;
        _config = configuration;
        _logger = logger;
        _paymentNotificationService = paymentNotificationService;
        _blockchain = blockchain;

        var clientId = configuration["PayOS:ClientId"];
        var apiKey = configuration["PayOS:ApiKey"];
        var checksumKey = configuration["PayOS:ChecksumKey"];

        if (string.IsNullOrWhiteSpace(clientId) || string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(checksumKey))
            throw new InvalidOperationException("PayOS 配置信息缺失，请检查 appsettings.json。");

        var options = new PayOSOptions
        {
            ClientId = clientId,
            ApiKey = apiKey,
            ChecksumKey = checksumKey
        };

        _payOs = new PayOSClient(options);
    }

    // ================== Lấy danh sách payment ==================
    [HttpGet]
    public async Task<PagedResult<Payment>> List([FromQuery] QueryParameters p)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");

        var q = _db.Payments.Include(x => x.Invoice).AsQueryable();
        if (!isManager && uid != null)
        {
            q = q.Where(x => x.Invoice != null && x.Invoice.UserId == uid);
        }

        return await q.OrderByDescending(x => x.PaidAtUtc ?? x.CreatedAtUtc)
                      .ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Payment>> Get(Guid id)
    {
        var payment = await _db.Payments
            .Include(x => x.Invoice)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (payment is null) return NotFound();

        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && payment.Invoice?.UserId != uid)
            return Forbid();

        return payment;
    }

    // ================== Tạo link VNPay cho Invoice ==================

    [HttpPost("{invoiceId:guid}/create-vnpay-link")]
    public async Task<IActionResult> CreateVnPayLink(Guid invoiceId)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Apartment)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);

        if (invoice is null)
            return NotFound("Invoice not found");

        // Chỉ cư dân của hóa đơn hoặc Manager mới được tạo link
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");

        if (!isManager && uid != null && invoice.UserId != uid)
            return Forbid("Bạn không có quyền thanh toán hóa đơn này");

        // Tạo payment pending
        var payment = new Payment
        {
            InvoiceId = invoice.Id,
            Amount = invoice.TotalAmount,
            Method = PaymentMethod.VNPay,
            Status = PaymentStatus.Pending,
            TransactionCode = Guid.NewGuid().ToString("N") // sẽ override ngay sau
        };

        // dùng Id làm TxnRef
        _db.Payments.Add(payment);
        await _db.SaveChangesAsync();

        var orderInfo =
            $"Thanh toán hóa đơn {invoice.Month}/{invoice.Year} cho căn {invoice.Apartment?.Code ?? ""}";

        var paymentUrl = _vnPay.CreatePaymentUrl(payment.Id, payment.Amount, orderInfo, HttpContext);

        // TransactionCode = vnp_TxnRef
        payment.TransactionCode = payment.Id.ToString("N");
        await _db.SaveChangesAsync();

        return Ok(new
        {
            paymentId = payment.Id,
            paymentUrl,
            transactionCode = payment.TransactionCode
        });
    }

    // ================== PayOS 集成 ==================
    [HttpPost("{invoiceId:guid}/create-payos-link")]
    public async Task<IActionResult> CreatePayOsLink(Guid invoiceId, [FromBody] CreatePayOsLinkRequest? request)
    {
        try
        {
            _logger.LogInformation("Tạo PayOS link cho invoice {InvoiceId}", invoiceId);

            var invoice = await _db.Invoices
                .Include(i => i.Apartment)
                .FirstOrDefaultAsync(i => i.Id == invoiceId);

            if (invoice is null)
            {
                _logger.LogWarning("Invoice {InvoiceId} không tồn tại", invoiceId);
                return NotFound("Invoice not found");
            }

            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var isManager = User.IsInRole("Manager");

            if (!isManager && uid != null && invoice.UserId != uid)
            {
                _logger.LogWarning("User {UserId} không có quyền thanh toán invoice {InvoiceId}", uid, invoiceId);
                return Forbid("Bạn không có quyền thanh toán hóa đơn này");
            }

            if (invoice.TotalAmount <= 0)
            {
                _logger.LogWarning("Invoice {InvoiceId} có số tiền không hợp lệ: {Amount}", invoiceId, invoice.TotalAmount);
                return BadRequest("Số tiền hóa đơn không hợp lệ");
            }

            var payOsAmount = ConvertToPayOsAmount(invoice.TotalAmount);
            _logger.LogInformation("Số tiền PayOS: {Amount} VND -> {PayOsAmount}", invoice.TotalAmount, payOsAmount);

            var orderCode = GeneratePayOsOrderCode();
            var payment = new Payment
            {
                InvoiceId = invoice.Id,
                Amount = invoice.TotalAmount,
                Method = PaymentMethod.PayOS,
                Status = PaymentStatus.Pending,
                TransactionCode = orderCode.ToString()
            };

            _db.Payments.Add(payment);
            await _db.SaveChangesAsync();
            _logger.LogInformation("Đã tạo Payment {PaymentId} với OrderCode {OrderCode}", payment.Id, orderCode);

            var description = BuildPayOsDescription(request?.Description, invoice);

            var cancelUrl = request?.CancelUrl
                ?? _config["PayOS:CancelUrl"]
                ?? throw new InvalidOperationException("Thiếu PayOS CancelUrl trong appsettings.json");

            var returnUrl = request?.ReturnUrl
                ?? _config["PayOS:ReturnUrl"]
                ?? throw new InvalidOperationException("Thiếu PayOS ReturnUrl trong appsettings.json");

            // Append invoiceId to callback URLs so we can pass it to deep link
            returnUrl += $"?invoiceId={invoiceId}";
            cancelUrl += $"?invoiceId={invoiceId}";

            _logger.LogInformation("PayOS URLs - Return: {ReturnUrl}, Cancel: {CancelUrl}", returnUrl, cancelUrl);

            var paymentRequest = new CreatePaymentLinkRequest
            {
                OrderCode = orderCode,
                Amount = payOsAmount,
                Description = description,
                CancelUrl = cancelUrl,
                ReturnUrl = returnUrl,
                Items = new List<PaymentLinkItem>
                {
                    new PaymentLinkItem
                    {
                        Name = $"Invoice {invoice.Apartment?.Code ?? "N/A"}",
                        Quantity = 1,
                        Price = payOsAmount
                    }
                }
            };

            PayOS.Models.V2.PaymentRequests.CreatePaymentLinkResponse payOsResult;
            try
            {
                _logger.LogInformation("Gọi PayOS API với OrderCode {OrderCode}, Amount {Amount}", orderCode, payOsAmount);
                payOsResult = await _payOs.PaymentRequests.CreateAsync(paymentRequest);
            }
            catch (Exception ex) when (ex.GetType().Name == "PayOSException")
            {
                _logger.LogError(ex, "PayOS trả về lỗi khi tạo link cho invoice {InvoiceId}", invoiceId);
                return StatusCode(502, new { error = "PayOSError", message = ex.Message });
            }
            catch (HttpRequestException httpEx)
            {
                _logger.LogError(httpEx, "Không thể kết nối PayOS");
                return StatusCode(502, new { error = "PayOSConnectionError", message = "Không thể kết nối PayOS, vui lòng thử lại sau." });
            }

            payment.TransactionRef = payOsResult.PaymentLinkId;
            await _db.SaveChangesAsync();

            _logger.LogInformation("PayOS link tạo thành công: {CheckoutUrl}", payOsResult.CheckoutUrl);

            return Ok(new
            {
                paymentId = payment.Id,
                checkoutUrl = payOsResult.CheckoutUrl,
                orderCode = payment.TransactionCode,
                qrCode = payOsResult.QrCode
            });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogError(ex, "Lỗi cấu hình PayOS: {Message}", ex.Message);
            return StatusCode(500, new { error = "Lỗi cấu hình PayOS", message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi tạo PayOS link cho invoice {InvoiceId}: {Message}", invoiceId, ex.Message);
            return StatusCode(500, new { error = "Lỗi khi tạo link thanh toán PayOS", message = ex.Message });
        }
    }

    // ================== PayOS Return/Cancel (user redirect về) ==================
    [HttpGet("payos-return")]
    [AllowAnonymous]
    public IActionResult PayOsReturn([FromQuery] string? orderCode)
    {
        // PayOS sẽ redirect về đây sau khi thanh toán thành công
        // Redirect thẳng về Flutter app bằng deep link
        _logger.LogInformation("PayOS return called for orderCode {OrderCode}", orderCode);
        return Redirect($"icitizen://payment/success?orderCode={orderCode ?? "unknown"}");
    }

    [HttpGet("payos-cancel")]
    [AllowAnonymous]
    public IActionResult PayOsCancel([FromQuery] string? orderCode)
    {
        // PayOS sẽ redirect về đây nếu user hủy thanh toán
        _logger.LogInformation("PayOS cancel called for orderCode {OrderCode}", orderCode);
        return Redirect($"icitizen://payment/cancelled?orderCode={orderCode ?? "unknown"}");
    }

    [HttpPost("payos/webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> PayOsWebhook([FromBody] Webhook body)
    {
        try
        {
            // DEV: cố gắng verify chữ ký, nếu lỗi vẫn tiếp tục xử lý để tránh kẹt trạng thái
            try
            {
                await _payOs.Webhooks.VerifyAsync(body);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PayOS VerifyAsync failed, continue handling webhook in DEV");
            }

            var data = body.Data;
            var orderCode = data.OrderCode.ToString();
            if (string.IsNullOrWhiteSpace(orderCode))
                return Ok(new { message = "orderCode missing" });

            var payment = await _db.Payments
                .Include(p => p.Invoice)
                .FirstOrDefaultAsync(p => p.TransactionCode == orderCode);

            if (payment == null)
                return Ok(new { message = "Payment not found" });

            var amount = data.Amount;
            var expected = ConvertToPayOsAmount(payment.Amount);
            if (amount != expected)
            {
                _logger.LogWarning("PayOS 金额不匹配，orderCode={OrderCode}, webhook={WebhookAmount}, expected={Expected}", orderCode, amount, expected);
                return BadRequest(new { message = "Amount mismatch" });
            }

            var transactionId = data.PaymentLinkId ?? data.Reference;

            if (body.Success)
            {
                if (payment.Status != PaymentStatus.Success)
                {
                    payment.Status = PaymentStatus.Success;
                    payment.PaidAtUtc = DateTime.UtcNow;
                    payment.TransactionRef = transactionId ?? payment.TransactionRef;
                    await UpdateInvoiceStatus(payment.InvoiceId);
                    await _db.SaveChangesAsync();
                    
                    // Notify clients via SignalR
                    await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
                    _logger.LogInformation("PayOS payment {PaymentId} confirmed successfully, notification sent", payment.Id);
                }
                return Ok(new { message = "Payment confirmed" });
            }

            payment.Status = PaymentStatus.Failed;
            await _db.SaveChangesAsync();
            
            // Notify clients about failed payment
            await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
            _logger.LogInformation("PayOS payment {PaymentId} marked as failed", payment.Id);
            
            return Ok(new { message = $"Payment marked as failed ({body.Code})" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "PayOS webhook xử lý thất bại");
            return BadRequest(new { message = ex.Message });
        }
    }

    // ================== PayOS QR cho Admin ==================

    /// <summary>
    /// Tạo QR PayOS cho một hóa đơn (dùng trong trang quản lý QR).
    /// </summary>
    [HttpPost("{invoiceId:guid}/generate-payos-qr")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> GeneratePayOsQr(Guid invoiceId)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Apartment)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);

        if (invoice == null)
            return NotFound("Invoice not found");

        if (invoice.TotalAmount <= 0)
            return BadRequest("Invoice amount must be > 0.");

        // 1) Tạo Payment mới trong DB
        var payment = new Payment
        {
            InvoiceId = invoice.Id,
            Amount = invoice.TotalAmount,
            Method = PaymentMethod.PayOS,
            Status = PaymentStatus.Pending
        };
        _db.Payments.Add(payment);
        await _db.SaveChangesAsync();

        // 2) Gọi PayOS tạo link
        // OrderCode cần là int và unique enough
        var orderCode = (int)(DateTimeOffset.UtcNow.ToUnixTimeSeconds() % int.MaxValue);
        payment.TransactionCode = orderCode.ToString();

        // Dùng helper chung để bảo đảm mô tả ASCII, không dấu và tối đa 25 ký tự
        var description = BuildPayOsDescription(null, invoice);
        var payOsAmount = ConvertToPayOsAmount(payment.Amount);

        PayOS.Models.V2.PaymentRequests.CreatePaymentLinkResponse payOsResult;
        try
        {
            var request = new CreatePaymentLinkRequest
            {
                OrderCode = orderCode,
                Amount = payOsAmount,
                Description = description,
                ReturnUrl = _config["PayOS:ReturnUrl"],
                CancelUrl = _config["PayOS:CancelUrl"]
            };

            _logger.LogInformation("Admin tạo QR PayOS cho invoice {InvoiceId}, orderCode {OrderCode}", invoiceId, orderCode);
            payOsResult = await _payOs.PaymentRequests.CreateAsync(request);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Không thể tạo link PayOS cho invoice {InvoiceId}", invoiceId);
            return StatusCode(502, new { error = "PayOS", message = ex.Message });
        }

        payment.TransactionRef = payOsResult.PaymentLinkId;
        await _db.SaveChangesAsync();

        return Ok(new
        {
            paymentId = payment.Id,
            amount = payment.Amount,
            qrData = payOsResult.CheckoutUrl,
            checkoutUrl = payOsResult.CheckoutUrl,
            orderCode,
            invoiceInfo = new
            {
                invoice.Id,
                invoice.Month,
                invoice.Year,
                apartmentCode = invoice.Apartment?.Code,
                type = invoice.Type.ToString()
            }
        });
    }

    // ================== VNPay Return (user redirect về) ==================
    // VNPay sẽ redirect browser về đây với query ?vnp_...

    [HttpGet("vnpay-return")]
    [AllowAnonymous]
    public async Task<IActionResult> VnPayReturn()
    {
        var query = Request.Query;

        if (!_vnPay.ValidateSignature(query))
            return Content("Invalid signature");

        var data = _vnPay.GetVnPayData(query);
        var responseCode = GetDictionaryValue(data, "vnp_ResponseCode");
        var txnRef = GetDictionaryValue(data, "vnp_TxnRef");
        var vnTranNo = GetDictionaryValue(data, "vnp_TransactionNo");

        if (string.IsNullOrEmpty(txnRef))
            return Content("Missing vnp_TxnRef");

        var payment = await _db.Payments
            .Include(x => x.Invoice)
            .FirstOrDefaultAsync(x => x.TransactionCode == txnRef);

        if (payment == null)
            return Content("Payment not found");

        if (payment.Status == PaymentStatus.Success)
        {
            _logger.LogInformation("VNPay payment {PaymentId} already processed", payment.Id);
            return Redirect($"icitizen://payment/success?invoiceId={payment.InvoiceId}");
        }

        if (responseCode == "00")
        {
            payment.Status = PaymentStatus.Success;
            payment.PaidAtUtc = DateTime.UtcNow;
            payment.TransactionRef = vnTranNo;

            await UpdateInvoiceStatus(payment.InvoiceId);
            await _db.SaveChangesAsync();
            
            // Notify clients via SignalR
            await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
            _logger.LogInformation("VNPay payment {PaymentId} confirmed successfully, invoice {InvoiceId}", payment.Id, payment.InvoiceId);
            
            return Redirect($"icitizen://payment/success?invoiceId={payment.InvoiceId}");
        }
        else
        {
            payment.Status = PaymentStatus.Failed;
            await _db.SaveChangesAsync();
            
            // Notify clients about failed payment
            await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);

            return Redirect($"icitizen://payment/failed?error={responseCode}&invoiceId={payment.InvoiceId}");
        }
    }
    // ================== VNPay IPN (server -> server) ==================
    // IPN đảm bảo cập nhật ngay cả khi user tắt trình duyệt

    [HttpGet("vnpay-ipn")]
    [AllowAnonymous]
    public async Task<IActionResult> VnPayIpn()
    {
        var query = Request.Query;

        if (!_vnPay.ValidateSignature(query))
        {
            return Ok(new { RspCode = "97", Message = "Invalid signature" });
        }

        var data = _vnPay.GetVnPayData(query);
        var responseCode = GetDictionaryValue(data, "vnp_ResponseCode");
        var transactionStatus = GetDictionaryValue(data, "vnp_TransactionStatus");
        var txnRef = GetDictionaryValue(data, "vnp_TxnRef");
        var amountStr = GetDictionaryValue(data, "vnp_Amount");
        var vnTranNo = GetDictionaryValue(data, "vnp_TransactionNo");

        if (string.IsNullOrEmpty(txnRef))
            return Ok(new { RspCode = "01", Message = "Order not found" });

        var payment = await _db.Payments
            .Include(x => x.Invoice)
            .FirstOrDefaultAsync(x => x.TransactionCode == txnRef);

        if (payment == null)
            return Ok(new { RspCode = "01", Message = "Order not found" });

        // kiểm tra số tiền
        if (long.TryParse(amountStr, out var vnAmount))
        {
            // VNPay gửi *100
            var amount = vnAmount / 100m;
            if (amount != payment.Amount)
                return Ok(new { RspCode = "04", Message = "Invalid amount" });
        }

        if (payment.Status == PaymentStatus.Success)
            return Ok(new { RspCode = "00", Message = "Order already confirmed" });

        // ResponseCode = "00" & TransactionStatus = "00" => thành công
        if (responseCode == "00" && transactionStatus == "00")
        {
            payment.Status = PaymentStatus.Success;
            payment.PaidAtUtc = DateTime.UtcNow;
            payment.TransactionRef = vnTranNo;

            await UpdateInvoiceStatus(payment.InvoiceId);
            await _db.SaveChangesAsync();
            
            // Notify clients via SignalR
            await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
            _logger.LogInformation("VNPay IPN payment {PaymentId} confirmed successfully", payment.Id);
            
            return Ok(new { RspCode = "00", Message = "Confirm Success" });
        }
        else
        {
            payment.Status = PaymentStatus.Failed;
            await _db.SaveChangesAsync();
            
            // Notify clients about failed payment
            await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
            
            return Ok(new { RspCode = "02", Message = "Payment failed" });
        }
    }

    // ================== API cho Flutter polling trạng thái ==================

    [HttpGet("{id:guid}/status")]
    [AllowAnonymous]
    public async Task<IActionResult> GetStatus(Guid id)
    {
        var payment = await _db.Payments
            .Include(p => p.Invoice)
            .FirstOrDefaultAsync(p => p.Id == id);

        if (payment == null) return NotFound();

        // **AUTO-SYNC**: If payment is still Pending, actively check PayOS status
        if (payment.Status == PaymentStatus.Pending && !string.IsNullOrEmpty(payment.TransactionCode))
        {
            try
            {
                _logger.LogInformation("⏳ Auto-syncing payment {PaymentId} status from PayOS (OrderCode: {OrderCode})", 
                    payment.Id, payment.TransactionCode);

                var orderCodeInt = int.Parse(payment.TransactionCode);
                var paymentLinkInfo = await _payOs.PaymentRequests.GetAsync(orderCodeInt);

                if (paymentLinkInfo != null)
                {
                    var payosStatus = paymentLinkInfo.Status.ToString().ToLowerInvariant();
                    _logger.LogInformation("📊 PayOS status for payment {PaymentId}: {Status}", payment.Id, payosStatus);

                    if (payosStatus == "paid")
                    {
                        // Payment succeeded! Update payment and invoice
                        payment.Status = PaymentStatus.Success;
                        payment.PaidAtUtc = DateTime.UtcNow;
                        payment.TransactionRef = paymentLinkInfo.Id ?? payment.TransactionRef;
                        payment.ErrorCode = null;
                        payment.ErrorMessage = null;

                        // Update invoice status
                        await UpdateInvoiceStatus(payment.InvoiceId);

                        // Ghi lên blockchain để minh bạch
                        if (payment.Invoice != null)
                        {
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

                        // If invoice is Service type, auto-approve amenity booking
                        if (payment.Invoice?.Type == InvoiceType.Service)
                        {
                            var booking = await _db.AmenityBookings
                                .Where(b => b.UserId == payment.Invoice.UserId &&
                                           b.StartTimeUtc.Date == payment.Invoice.PeriodStart.Date &&
                                           b.EndTimeUtc.Date == payment.Invoice.PeriodEnd.Date &&
                                           Math.Abs((b.Price ?? 0) - payment.Invoice.TotalAmount) < 0.01m &&
                                           b.Status == AmenityBookingStatus.Pending)
                                .FirstOrDefaultAsync();

                            if (booking != null)
                            {
                                booking.Status = AmenityBookingStatus.Approved;
                                booking.PaymentStatus = PaymentStatus.Success;
                                _logger.LogInformation("✅ Auto-approved amenity booking {BookingId}", booking.Id);
                            }
                        }

                        await _db.SaveChangesAsync();
                        
                        // Notify via SignalR
                        await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
                        
                        _logger.LogInformation("✅ Payment {PaymentId} auto-synced as SUCCESS from PayOS", payment.Id);
                    }
                    else if (payosStatus == "cancelled")
                    {
                        payment.Status = PaymentStatus.Failed;
                        payment.ErrorCode = "CANCELLED";
                        payment.ErrorMessage = "Payment cancelled by user";
                        await _db.SaveChangesAsync();
                        await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
                        _logger.LogInformation("❌ Payment {PaymentId} marked as FAILED (cancelled)", payment.Id);
                    }
                    // If status is still "pending", keep as is and wait for next poll
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "⚠️ Could not auto-sync payment {PaymentId} from PayOS: {Message}", payment.Id, ex.Message);
                // Continue to return current status even if sync fails
            }
        }

        return Ok(new
        {
            paymentId = payment.Id,
            status = payment.Status.ToString(),
            invoiceId = payment.InvoiceId,
            invoiceStatus = payment.Invoice?.Status.ToString(),
            amount = payment.Amount
        });
    }

    // ================== Blockchain History APIs ==================
    
    /// <summary>
    /// Lấy lịch sử blockchain transactions của user hiện tại
    /// </summary>
    [HttpGet("my-blockchain-history")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMyBlockchainHistory()
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized();

        var payments = await _db.Payments
            .Include(p => p.Invoice)
            .ThenInclude(i => i!.Apartment)
            .Include(p => p.Invoice)
            .ThenInclude(i => i!.User)
            .Where(p => p.Invoice != null && p.Invoice.UserId == uid 
                     && p.Status == PaymentStatus.Success 
                     && !string.IsNullOrEmpty(p.BlockchainTxHash))
            .OrderByDescending(p => p.PaidAtUtc)
            .ToListAsync();

        var result = payments.Select(p => new
            {
                transactionHash = p.BlockchainTxHash,
                invoiceId = p.Invoice!.Id,
                apartmentCode = p.Invoice.Apartment?.Code ?? "N/A",
                userName = p.Invoice.User?.FullName ?? "N/A",
                amount = p.Amount,
                paymentMethod = p.Method.ToString(),
                timestamp = p.PaidAtUtc,
                status = "Success",
                invoiceMonth = p.Invoice.Month,
                invoiceYear = p.Invoice.Year
            }).ToList<object>();

        return Ok(result);
    }

    /// <summary>
    /// Lấy tất cả blockchain transactions (Admin only)
    /// </summary>
    [HttpGet("all-blockchain-history")]
    [Authorize(Roles = "Manager")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAllBlockchainHistory()
    {
        var payments = await _db.Payments
            .Include(p => p.Invoice)
            .ThenInclude(i => i!.Apartment)
            .Include(p => p.Invoice)
            .ThenInclude(i => i!.User)
            .Where(p => p.Status == PaymentStatus.Success 
                     && !string.IsNullOrEmpty(p.BlockchainTxHash))
            .OrderByDescending(p => p.PaidAtUtc)
            .ToListAsync();

        var result = payments.Select(p => new
            {
                transactionHash = p.BlockchainTxHash,
                invoiceId = p.Invoice?.Id ?? Guid.Empty,
                apartmentCode = p.Invoice?.Apartment?.Code ?? "N/A",
                userName = p.Invoice?.User?.FullName ?? "N/A",
                amount = p.Amount,
                paymentMethod = p.Method.ToString(),
                timestamp = p.PaidAtUtc,
                status = "Success",
                invoiceMonth = p.Invoice?.Month ?? 0,
                invoiceYear = p.Invoice?.Year ?? 0
            }).ToList<object>();

        return Ok(result);
    }

    /// <summary>
    /// Lấy chi tiết blockchain transaction theo hash
    /// </summary>
    [HttpGet("blockchain/{txHash}")]
    public async Task<IActionResult> GetBlockchainTransaction(string txHash)
    {
        var payment = await _db.Payments
            .Include(p => p.Invoice)
            .ThenInclude(i => i!.Apartment)
            .FirstOrDefaultAsync(p => p.BlockchainTxHash == txHash);

        if (payment == null)
            return NotFound(new { message = "Transaction not found" });

        // Check authorization
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && (payment.Invoice == null || payment.Invoice.UserId != uid))
            return Forbid();

        // Get blockchain info (if available)
        Dictionary<string, object>? blockchainInfo = null;
        if (payment.Invoice != null)
        {
            try
            {
                var bcInfo = await _blockchain.GetPaymentAsync(payment.Invoice.Id.ToString());
                if (bcInfo != null)
                {
                    blockchainInfo = new Dictionary<string, object>
                    {
                        ["invoiceId"] = bcInfo.InvoiceId,
                        ["apartmentId"] = bcInfo.ApartmentId,
                        ["amount"] = bcInfo.Amount,
                        ["timestamp"] = bcInfo.Timestamp,
                        ["paymentMethod"] = bcInfo.PaymentMethod,
                        ["status"] = bcInfo.Status
                    };
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not fetch blockchain info for payment {PaymentId}", payment.Id);
            }
        }

        return Ok(new
        {
            transactionHash = payment.BlockchainTxHash,
            paymentId = payment.Id,
            invoiceId = payment.Invoice?.Id,
            apartmentCode = payment.Invoice?.Apartment?.Code ?? "N/A",
            amount = payment.Amount,
            paymentMethod = payment.Method.ToString(),
            timestamp = payment.PaidAtUtc,
            status = payment.Status.ToString(),
            invoiceMonth = payment.Invoice?.Month,
            invoiceYear = payment.Invoice?.Year,
            blockchainInfo = blockchainInfo,
            isVerified = !string.IsNullOrEmpty(payment.BlockchainTxHash)
        });
    }

    /// <summary>
    /// Verify blockchain transaction
    /// </summary>
    [HttpGet("verify-blockchain/{txHash}")]
    public async Task<IActionResult> VerifyBlockchainTransaction(string txHash)
    {
        var payment = await _db.Payments
            .FirstOrDefaultAsync(p => p.BlockchainTxHash == txHash);

        if (payment == null)
            return NotFound(new { verified = false, message = "Transaction not found" });

        // Simple verification: check if transaction exists and payment is successful
        var isVerified = !string.IsNullOrEmpty(payment.BlockchainTxHash) 
                      && payment.Status == PaymentStatus.Success;

        return Ok(new
        {
            verified = isVerified,
            isValid = isVerified,
            transactionHash = payment.BlockchainTxHash,
            status = payment.Status.ToString()
        });
    }

    /// <summary>
    /// Lấy blockchain info cho invoice
    /// </summary>
    [HttpGet("invoice/{invoiceId:guid}/blockchain")]
    public async Task<IActionResult> GetInvoiceBlockchainInfo(Guid invoiceId)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Apartment)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);

        if (invoice == null)
            return NotFound();

        // Check authorization
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && invoice.UserId != uid)
            return Forbid();

        var payment = await _db.Payments
            .Where(p => p.InvoiceId == invoiceId 
                     && p.Status == PaymentStatus.Success 
                     && !string.IsNullOrEmpty(p.BlockchainTxHash))
            .OrderByDescending(p => p.PaidAtUtc)
            .FirstOrDefaultAsync();

        if (payment == null)
            return NotFound(new { message = "No blockchain record for this invoice" });

        return Ok(new
        {
            blockchainTxHash = payment.BlockchainTxHash,
            paymentId = payment.Id,
            amount = payment.Amount,
            timestamp = payment.PaidAtUtc
        });
    }
    
    // ================== Helper cập nhật trạng thái Invoice ==================
    private async Task UpdateInvoiceStatus(Guid invoiceId)
    {
        var invoice = await _db.Invoices.FindAsync(invoiceId);
        if (invoice == null) return;

        var totalPaid = await _db.Payments
            .Where(p => p.InvoiceId == invoiceId && p.Status == PaymentStatus.Success)
            .SumAsync(p => (decimal?)p.Amount) ?? 0;

        // Cập nhật trạng thái invoice dựa trên số tiền đã thanh toán
        if (totalPaid >= invoice.TotalAmount)
        {
            invoice.Status = InvoiceStatus.Paid;
        }
        else if (totalPaid > 0)
        {
            invoice.Status = InvoiceStatus.PartiallyPaid;
        }
        else
        {
            invoice.Status = InvoiceStatus.Unpaid;
        }
        
        // KHÔNG save ở đây - để caller save sau khi đã set payment status
        // await _db.SaveChangesAsync(); // REMOVED
    }

    private static string? GetDictionaryValue(IDictionary<string, string> dictionary, string key)
        => dictionary.TryGetValue(key, out var value) ? value : null;

    private static long GeneratePayOsOrderCode()
    {
        var milliseconds = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var orderCode = milliseconds % 1_000_000_000_000; // tối đa 12 chữ số
        if (orderCode < 100_000_000) orderCode += 100_000_000; // tối thiểu 9 chữ số
        return orderCode;
    }

    private static int ConvertToPayOsAmount(decimal amount)
    {
        if (amount <= 0) throw new InvalidOperationException("Số tiền phải lớn hơn 0");
        return (int)Math.Round(amount, MidpointRounding.AwayFromZero);
    }

    private static string BuildPayOsDescription(string? overrideText, Invoice invoice)
    {
        var raw = overrideText;
        if (string.IsNullOrWhiteSpace(raw))
        {
            raw = $"HOADON {invoice.Month}/{invoice.Year}";
        }

        var normalized = raw.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var c in normalized)
        {
            var cat = CharUnicodeInfo.GetUnicodeCategory(c);
            if (cat != UnicodeCategory.NonSpacingMark)
            {
                sb.Append(c);
            }
        }

        var ascii = sb.ToString()
            .Normalize(NormalizationForm.FormC)
            .Replace(" ", string.Empty)
            .ToUpperInvariant();

        return ascii.Length > 25 ? ascii[..25] : ascii;
    }

    // ================== Helper HTML Response ==================
    private static string GetSuccessHtml(string gateway, string message)
    {
        return $@"
<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Thanh toán thành công</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
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
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            animation: slideUp 0.5s ease-out;
        }}
        @keyframes slideUp {{
            from {{ transform: translateY(30px); opacity: 0; }}
            to {{ transform: translateY(0); opacity: 1; }}
        }}
        .success-icon {{
            width: 80px;
            height: 80px;
            background: #10b981;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: scaleIn 0.5s ease-out 0.2s both;
        }}
        @keyframes scaleIn {{
            from {{ transform: scale(0); }}
            to {{ transform: scale(1); }}
        }}
        .success-icon svg {{
            width: 48px;
            height: 48px;
            stroke: white;
            fill: none;
            stroke-width: 3;
            stroke-linecap: round;
            stroke-linejoin: round;
        }}
        h1 {{
            color: #1f2937;
            font-size: 28px;
            margin-bottom: 12px;
            font-weight: 700;
        }}
        .message {{
            color: #6b7280;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 24px;
        }}
        .gateway {{
            display: inline-block;
            background: #f3f4f6;
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 14px;
            color: #6b7280;
            margin-bottom: 24px;
        }}
        .close-btn {{
            background: #667eea;
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }}
        .close-btn:hover {{
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""success-icon"">
            <svg viewBox=""0 0 24 24"">
                <polyline points=""20 6 9 17 4 12""></polyline>
            </svg>
        </div>
        <h1>✅ Thanh toán thành công!</h1>
        <p class=""message"">{message}</p>
        <div class=""gateway"">🔐 {gateway}</div>
        <button class=""close-btn"" onclick=""window.close()"">Đóng cửa sổ</button>
    </div>
</body>
</html>";
    }

    private static string GetErrorHtml(string gateway, string title, string message)
    {
        return $@"
<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Thanh toán thất bại</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        .container {{
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            animation: slideUp 0.5s ease-out;
        }}
        @keyframes slideUp {{
            from {{ transform: translateY(30px); opacity: 0; }}
            to {{ transform: translateY(0); opacity: 1; }}
        }}
        .error-icon {{
            width: 80px;
            height: 80px;
            background: #ef4444;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: scaleIn 0.5s ease-out 0.2s both;
        }}
        @keyframes scaleIn {{
            from {{ transform: scale(0); }}
            to {{ transform: scale(1); }}
        }}
        .error-icon svg {{
            width: 48px;
            height: 48px;
            stroke: white;
            fill: none;
            stroke-width: 3;
            stroke-linecap: round;
            stroke-linejoin: round;
        }}
        h1 {{
            color: #1f2937;
            font-size: 28px;
            margin-bottom: 12px;
            font-weight: 700;
        }}
        .message {{
            color: #6b7280;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 24px;
        }}
        .gateway {{
            display: inline-block;
            background: #f3f4f6;
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 14px;
            color: #6b7280;
            margin-bottom: 24px;
        }}
        .close-btn {{
            background: #ef4444;
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }}
        .close-btn:hover {{
            background: #dc2626;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
        }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""error-icon"">
            <svg viewBox=""0 0 24 24"">
                <line x1=""18"" y1=""6"" x2=""6"" y2=""18""></line>
                <line x1=""6"" y1=""6"" x2=""18"" y2=""18""></line>
            </svg>
        </div>
        <h1>❌ {title}</h1>
        <p class=""message"">{message}</p>
        <div class=""gateway"">🔐 {gateway}</div>
        <button class=""close-btn"" onclick=""window.close()"">Đóng cửa sổ</button>
    </div>
</body>
</html>";
    }

    private static string GetCancelHtml(string gateway, string message)
    {
        return $@"
<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Đã hủy thanh toán</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }}
        .container {{
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            animation: slideUp 0.5s ease-out;
        }}
        @keyframes slideUp {{
            from {{ transform: translateY(30px); opacity: 0; }}
            to {{ transform: translateY(0); opacity: 1; }}
        }}
        .warning-icon {{
            width: 80px;
            height: 80px;
            background: #f59e0b;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: scaleIn 0.5s ease-out 0.2s both;
        }}
        @keyframes scaleIn {{
            from {{ transform: scale(0); }}
            to {{ transform: scale(1); }}
        }}
        .warning-icon svg {{
            width: 48px;
            height: 48px;
            stroke: white;
            fill: none;
            stroke-width: 3;
            stroke-linecap: round;
            stroke-linejoin: round;
        }}
        h1 {{
            color: #1f2937;
            font-size: 28px;
            margin-bottom: 12px;
            font-weight: 700;
        }}
        .message {{
            color: #6b7280;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 24px;
        }}
        .gateway {{
            display: inline-block;
            background: #f3f4f6;
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 14px;
            color: #6b7280;
            margin-bottom: 24px;
        }}
        .close-btn {{
            background: #f59e0b;
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }}
        .close-btn:hover {{
            background: #d97706;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
        }}
    </style>
</head>
<body>
    <div class=""container"">
        <div class=""warning-icon"">
            <svg viewBox=""0 0 24 24"">
                <path d=""M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z""></path>
                <line x1=""12"" y1=""9"" x2=""12"" y2=""13""></line>
                <line x1=""12"" y1=""17"" x2=""12.01"" y2=""17""></line>
            </svg>
        </div>
        <h1>⚠️ Đã hủy thanh toán</h1>
        <p class=""message"">{message}</p>
        <div class=""gateway"">🔐 {gateway}</div>
        <button class=""close-btn"" onclick=""window.close()"">Đóng cửa sổ</button>
    </div>
</body>
</html>";
    }
}

public class CreatePayOsLinkRequest
{
    public string? Description { get; set; }
    public string? CancelUrl { get; set; }
    public string? ReturnUrl { get; set; }
}