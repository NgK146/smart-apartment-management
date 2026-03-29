using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PayOS;
using PayOS.Models.V2.PaymentRequests;
using System.Globalization;
using System.Text;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InvoicesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly PayOSClient _payOs;
    private readonly ILogger<InvoicesController> _logger;
    private readonly IConfiguration _config;

    public InvoicesController(
        ApplicationDbContext db,
        PayOSClient payOs,
        ILogger<InvoicesController> logger,
        IConfiguration config)
    {
        _db = db;
        _payOs = payOs;
        _logger = logger;
        _config = config;
    }

    // GET /api/Invoices/my-invoices: Lấy hóa đơn của cư dân đang đăng nhập
    [HttpGet("my-invoices")]
    public async Task<PagedResult<object>> GetMyInvoices(
        [FromQuery] int page = 1, 
        [FromQuery] int pageSize = 20, 
        [FromQuery] string? status = null)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (uid == null)
            return new PagedResult<object>(new List<object>(), 0, page, pageSize);

        var query = _db.Invoices
            .Include(i => i.Apartment)
            .Include(i => i.Lines)
            .Where(i => i.UserId == uid && !i.IsDeleted)
            .AsQueryable();

        // Filter by status if provided
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (Enum.TryParse<InvoiceStatus>(status, true, out var invoiceStatus))
            {
                query = query.Where(i => i.Status == invoiceStatus);
            }
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(i => i.Year)
            .ThenByDescending(i => i.Month)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new
            {
                i.Id,
                Status = i.Status.ToString(),
                Type = i.Type.ToString(),
                i.TotalAmount,
                i.Month,
                i.Year,
                i.DueDate,
                i.PeriodStart,
                i.PeriodEnd,
                i.ApartmentId,
                Apartment = i.Apartment != null ? new { i.Apartment.Code } : null,
                Lines = i.Lines.Select(l => new
                {
                    l.FeeName,
                    l.Description,
                    l.Amount,
                    l.Quantity,
                    l.UnitPrice
                }).ToList()
            })
            .ToListAsync();

        return new PagedResult<object>(items, total, page, pageSize);
    }

    // POST /api/Invoices: Tạo hóa đơn mới (Admin/Manager only)
    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Create([FromBody] CreateInvoiceRequest request)
    {
        // Validate apartment exists
        var apartment = await _db.Apartments.FindAsync(request.ApartmentId);
        if (apartment == null)
            return NotFound("Không tìm thấy căn hộ");

        // Get resident for this apartment
        var resident = await _db.ResidentProfiles
            .FirstOrDefaultAsync(r => r.ApartmentId == request.ApartmentId && !r.IsDeleted);

        // Calculate period dates
        var periodStart = new DateTime(request.Year, request.Month, 1);
        var periodEnd = periodStart.AddMonths(1).AddDays(-1);

        // Create invoice
        var invoice = new Invoice
        {
            ApartmentId = request.ApartmentId,
            UserId = resident?.UserId,
            Type = InvoiceType.Utility, // Default to Utility for admin-created invoices
            Month = request.Month,
            Year = request.Year,
            PeriodStart = periodStart,
            PeriodEnd = periodEnd,
            DueDate = request.DueDate,
            Status = InvoiceStatus.Unpaid,
            Lines = new List<InvoiceLine>()
        };

        // Add invoice lines
        foreach (var lineRequest in request.Lines)
        {
            invoice.Lines.Add(new InvoiceLine
            {
                FeeName = lineRequest.FeeName,
                Description = lineRequest.Description,
                Quantity = lineRequest.Quantity,
                UnitPrice = lineRequest.UnitPrice,
                Amount = lineRequest.Amount
            });
        }

        // Calculate total
        invoice.TotalAmount = invoice.Lines.Sum(l => l.Amount);

        _db.Invoices.Add(invoice);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            id = invoice.Id,
            message = "Tạo hóa đơn thành công",
            totalAmount = invoice.TotalAmount
        });
    }

    // GET /api/Invoices: Lấy danh sách hóa đơn (cho admin/manager)
    [HttpGet]
    [Authorize(Roles = "Manager")]
    public async Task<PagedResult<object>> List(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? status = null,
        [FromQuery] Guid? apartmentId = null,
        [FromQuery] int? month = null,
        [FromQuery] int? year = null)
    {
        var query = _db.Invoices
            .Include(i => i.Apartment)
            .Include(i => i.Lines)
            .Where(i => !i.IsDeleted)
            .AsQueryable();

        // Apply filters
        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<InvoiceStatus>(status, true, out var invoiceStatus))
        {
            query = query.Where(i => i.Status == invoiceStatus);
        }

        if (apartmentId.HasValue)
        {
            query = query.Where(i => i.ApartmentId == apartmentId.Value);
        }

        if (month.HasValue)
        {
            query = query.Where(i => i.Month == month.Value);
        }

        if (year.HasValue)
        {
            query = query.Where(i => i.Year == year.Value);
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(i => i.Year)
            .ThenByDescending(i => i.Month)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new
            {
                i.Id,
                Status = i.Status.ToString(),
                Type = i.Type.ToString(),
                i.TotalAmount,
                i.Month,
                i.Year,
                i.DueDate,
                i.PeriodStart,
                i.PeriodEnd,
                i.ApartmentId,
                Apartment = i.Apartment != null ? new { i.Apartment.Code } : null,
                Lines = i.Lines.Select(l => new
                {
                    l.FeeName,
                    l.Description,
                    l.Amount,
                    l.Quantity,
                    l.UnitPrice
                }).ToList()
            })
            .ToListAsync();

        return new PagedResult<object>(items, total, page, pageSize);
    }

    // GET /api/Invoices/{id}: Lấy chi tiết một hóa đơn
    [HttpGet("{id}")]
    public async Task<IActionResult> Get(Guid id)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Apartment)
            .Include(i => i.Lines)
            .FirstOrDefaultAsync(i => i.Id == id && !i.IsDeleted);

        if (invoice == null)
            return NotFound();

        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");

        // Security check: Residents can only view their own invoices
        if (!isManager && invoice.UserId != uid)
            return Forbid();

        return Ok(new
        {
            invoice.Id,
            Status = invoice.Status.ToString(),
            Type = invoice.Type.ToString(),
            invoice.TotalAmount,
            invoice.Month,
            invoice.Year,
            invoice.DueDate,
            invoice.PeriodStart,
            invoice.PeriodEnd,
            invoice.ApartmentId,
            Apartment = invoice.Apartment != null ? new { invoice.Apartment.Code } : null,
            Lines = invoice.Lines.Select(l => new
            {
                l.FeeName,
                l.Description,
                l.Amount,
                l.Quantity,
                l.UnitPrice
            }).ToList()
        });
    }

    // POST /api/Invoices/{id}/pay: Ghi nhận thanh toán thủ công
    [HttpPost("{id}/pay")]
    public async Task<IActionResult> Pay(Guid id, [FromBody] PayInvoiceRequest request)
    {
        var invoice = await _db.Invoices.FindAsync(id);
        if (invoice == null)
            return NotFound();

        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");

        // Security check
        if (!isManager && invoice.UserId != uid)
            return Forbid();

        // Create payment record
        var payment = new Payment
        {
            InvoiceId = invoice.Id,
            Amount = request.Amount,
            Method = Enum.TryParse<PaymentMethod>(request.Method, true, out var method) 
                ? method 
                : PaymentMethod.Cash,
            Status = PaymentStatus.Success,
            TransactionCode = request.TransactionRef ?? $"MANUAL-{DateTime.UtcNow:yyyyMMddHHmmss}",
            PaidAtUtc = DateTime.UtcNow
        };

        _db.Payments.Add(payment);

        // Update invoice status
        if (request.Amount >= invoice.TotalAmount)
        {
            invoice.Status = InvoiceStatus.Paid;
        }
        else if (request.Amount > 0)
        {
            invoice.Status = InvoiceStatus.PartiallyPaid;
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "Thanh toán thành công",
            paymentId = payment.Id,
            invoiceStatus = invoice.Status.ToString()
        });
    }

    // PUT /api/Invoices/{id}/confirm-manual-payment: BQL xác nhận thanh toán thủ công
    [HttpPut("{id}/confirm-manual-payment")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> ConfirmManualPayment(Guid id)
    {
        var invoice = await _db.Invoices.FindAsync(id);
        if (invoice == null)
            return NotFound();

        invoice.Status = InvoiceStatus.Paid;
        await _db.SaveChangesAsync();

        return NoContent();
    }

    // DELETE /api/Invoices/{id}: Xoá hóa đơn (soft delete)
    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var invoice = await _db.Invoices.FindAsync(id);
        if (invoice == null)
            return NotFound();

        invoice.IsDeleted = true;
        await _db.SaveChangesAsync();

        return NoContent();
    }

    // POST /api/Invoices/{id}/payos-payment: Tạo link thanh toán PayOS cho invoice
    [HttpPost("{id}/payos-payment")]
    public async Task<IActionResult> CreatePayOsPayment(Guid id)
    {
        try
        {
            var invoice = await _db.Invoices
                .Include(i => i.Apartment)
                .FirstOrDefaultAsync(i => i.Id == id);

            if (invoice == null)
                return NotFound("Invoice not found");

            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var isManager = User.IsInRole("Manager");

            if (!isManager && uid != null && invoice.UserId != uid)
                return Forbid("Bạn không có quyền thanh toán hóa đơn này");

            if (invoice.TotalAmount <= 0)
                return BadRequest("Số tiền hóa đơn không hợp lệ");

            var payOsAmount = ConvertToPayOsAmount(invoice.TotalAmount);
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

            var description = BuildPayOsDescription(invoice);
            var returnUrl = _config["PayOS:ReturnUrl"] + $"?invoiceId={id}";
            var cancelUrl = _config["PayOS:CancelUrl"] + $"?invoiceId={id}";

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

            var payOsResult = await _payOs.PaymentRequests.CreateAsync(paymentRequest);
            payment.TransactionRef = payOsResult.PaymentLinkId;
            await _db.SaveChangesAsync();

            _logger.LogInformation("Created PayOS payment {PaymentId} for invoice {InvoiceId}", payment.Id, id);

            return Ok(new
            {
                paymentId = payment.Id,
                checkoutUrl = payOsResult.CheckoutUrl
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating PayOS payment for invoice {InvoiceId}", id);
            return StatusCode(500, new { error = "Lỗi khi tạo link thanh toán", message = ex.Message });
        }
    }

    private static long GeneratePayOsOrderCode()
    {
        var milliseconds = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var orderCode = milliseconds % 1_000_000_000_000;
        if (orderCode < 100_000_000) orderCode += 100_000_000;
        return orderCode;
    }

    private static int ConvertToPayOsAmount(decimal amount)
    {
        if (amount <= 0) throw new InvalidOperationException("Số tiền phải lớn hơn 0");
        return (int)Math.Round(amount, MidpointRounding.AwayFromZero);
    }

    private static string BuildPayOsDescription(Invoice invoice)
    {
        var raw = $"HOADON {invoice.Month}/{invoice.Year}";
        var normalized = raw.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var c in normalized)
        {
            var cat = CharUnicodeInfo.GetUnicodeCategory(c);
            if (cat != UnicodeCategory.NonSpacingMark)
                sb.Append(c);
        }
        var ascii = sb.ToString().Normalize(NormalizationForm.FormC).Replace(" ", string.Empty).ToUpperInvariant();
        return ascii.Length > 25 ? ascii[..25] : ascii;
    }
}

// Request models
public record PayInvoiceRequest(decimal Amount, string Method, string? TransactionRef);

public record CreateInvoiceRequest(
    Guid ApartmentId,
    string Type,
    int Month,
    int Year,
    DateTime DueDate,
    List<CreateInvoiceLineRequest> Lines
);

public record CreateInvoiceLineRequest(
    string FeeName,
    string Description,
    decimal Quantity,
    decimal UnitPrice,
    decimal Amount
);
