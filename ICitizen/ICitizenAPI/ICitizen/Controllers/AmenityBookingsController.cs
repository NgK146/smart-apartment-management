using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using ICitizen.Models;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using PayOS;
using PayOS.Models.V2.PaymentRequests;
using System.Data;
using System.Globalization;
using System.Text;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AmenityBookingsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly ISmsService _smsService;
    private readonly ILogger<AmenityBookingsController> _logger;
    private readonly IInvoicePaymentService _invoicePaymentService;
    private readonly UserManager<AppUser> _userManager;
    private readonly IHubContext<SupportHub>? _supportHub;
    private readonly IHubContext<NotificationHub>? _notificationHub;
    private readonly PayOSClient _payOs;
    private readonly IConfiguration _config;

    private const string StaffHubGroup = "support-staff";
    
    public AmenityBookingsController(
        ApplicationDbContext db,
        IInvoicePaymentService invoicePaymentService,
        ISmsService smsService,
        ILogger<AmenityBookingsController> logger,
        UserManager<AppUser> userManager,
        PayOSClient payOs,
        IConfiguration config,
        IHubContext<SupportHub>? supportHub = null,
        IHubContext<NotificationHub>? notificationHub = null)
    {
        _db = db;
        _invoicePaymentService = invoicePaymentService;
        _smsService = smsService;
        _logger = logger;
        _userManager = userManager;
        _payOs = payOs;
        _config = config;
        _supportHub = supportHub;
        _notificationHub = notificationHub;
    }

    private static int ConvertToPayOsAmount(decimal amount)
    {
        if (amount <= 0) throw new InvalidOperationException("Số tiền phải lớn hơn 0");
        return (int)Math.Round(amount, MidpointRounding.AwayFromZero);
    }

    private static string BuildAmenityPayOsDescription(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            raw = "AMENITY";
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

    // Cư dân đặt lịch tiện ích; Manager duyệt. :contentReference[oaicite:20]{index=20}
    [HttpGet]
    [Authorize]
    public async Task<IActionResult> List([FromQuery] QueryParameters p, [FromQuery] AmenityBookingStatus? status = null)
    {
        try
        {
            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(uid)) return Unauthorized();
            
            var isManager = User.IsInRole("Manager");
            var q = _db.AmenityBookings.Include(b => b.Amenity).AsQueryable();
            if (!isManager) q = q.Where(b => b.UserId == uid);
            if (status.HasValue) q = q.Where(b => b.Status == status);
            q = q.OrderByDescending(x => x.CreatedAtUtc);

            var total = await q.CountAsync();
            var items = await q.Skip((p.Page - 1) * p.PageSize).Take(p.PageSize).ToListAsync();
            
            // Lấy user names một lần
            var userIds = items.Select(b => b.UserId).Distinct().ToList();
            Dictionary<string, string> userDict;
            if (userIds.Count > 0)
            {
                var users = await _db.Users.Where(u => userIds.Contains(u.Id)).Select(u => new { u.Id, u.UserName }).ToListAsync();
                userDict = users.ToDictionary(u => u.Id, u => u.UserName ?? "Unknown");
            }
            else
            {
                userDict = new Dictionary<string, string>();
            }
            
            // Lấy invoice IDs cho các booking có giá
            Dictionary<Guid, Guid?> invoiceDict = new();
            var bookingsWithPrice = items.Where(b => b.Price.HasValue && b.Price.Value > 0).ToList();
            if (bookingsWithPrice.Count > 0)
            {
                // Tìm invoices liên quan đến bookings (qua UserId, PeriodStart, PeriodEnd, Type = Service)
                var allInvoices = await _db.Invoices
                    .Where(i => i.Type == InvoiceType.Service && userIds.Contains(i.UserId ?? ""))
                    .ToListAsync();
                
                // Map booking to invoice (match by user, start/end time, và amount)
                foreach (var booking in bookingsWithPrice)
                {
                    var bookingPrice = booking.Price ?? 0m;
                    var invoice = allInvoices.FirstOrDefault(i => 
                        i.UserId == booking.UserId &&
                        i.PeriodStart.Date == booking.StartTimeUtc.Date &&
                        i.PeriodEnd.Date == booking.EndTimeUtc.Date &&
                        Math.Abs(i.TotalAmount - bookingPrice) < 0.01m);
                    invoiceDict[booking.Id] = invoice?.Id;
                }
            }
            
            // Map để include user name và invoiceId
            var result = items.Select(b => new {
                b.Id,
                b.AmenityId,
                amenityName = b.Amenity?.Name ?? "Unknown",
                b.UserId,
                userName = userDict.TryGetValue(b.UserId, out var name) ? name : "Unknown",
                startTimeUtc = b.StartTimeUtc,
                endTimeUtc = b.EndTimeUtc,
                status = b.Status.ToString(),
                price = b.Price,
                invoiceId = invoiceDict.TryGetValue(b.Id, out var invId) ? invId : (Guid?)null,
                createdAtUtc = b.CreatedAtUtc
            }).ToList();

            return Ok(new { page = p.Page, pageSize = p.PageSize, total, items = result });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách đặt lịch", message = ex.Message });
        }
    }

    // GET /api/AmenityBookings/availability?amenityId=...&weekStartUtc=...&slotMinutes=60&dayStart=6&dayEnd=22
    public record SlotDto(DateTime StartUtc, DateTime EndUtc, bool Available);
    [HttpGet("availability")]
    [Authorize]
    public async Task<IActionResult> Availability([FromQuery] Guid amenityId, [FromQuery] DateTime? weekStartUtc, [FromQuery] int slotMinutes = 60, [FromQuery] int dayStart = 6, [FromQuery] int dayEnd = 22)
    {
        if (slotMinutes <= 0) slotMinutes = 60;
        var startWeek = weekStartUtc.HasValue
            ? DateTime.SpecifyKind(weekStartUtc.Value.Date, DateTimeKind.Utc)
            : DateTime.UtcNow.Date;
        // lấy các booking Approved trong tuần
        var weekEnd = startWeek.AddDays(7);
        var approved = await _db.AmenityBookings
            .Where(x => x.AmenityId == amenityId && x.Status == AmenityBookingStatus.Approved && x.StartTimeUtc < weekEnd && x.EndTimeUtc > startWeek)
            .ToListAsync();
        var amenity = await _db.Amenities.FirstOrDefaultAsync(a => a.Id == amenityId);
        if (amenity?.OpenHourStart != null) dayStart = amenity.OpenHourStart.Value;
        if (amenity?.OpenHourEnd != null) dayEnd = amenity.OpenHourEnd.Value;

        var result = new List<SlotDto>();
        for (int d = 0; d < 7; d++)
        {
            var day = startWeek.AddDays(d);
            var dayStartUtc = new DateTime(day.Year, day.Month, day.Day, dayStart, 0, 0, DateTimeKind.Utc);
            var dayEndUtc = new DateTime(day.Year, day.Month, day.Day, dayEnd, 0, 0, DateTimeKind.Utc);
            for (var s = dayStartUtc; s < dayEndUtc; s = s.AddMinutes(slotMinutes))
            {
                var e = s.AddMinutes(slotMinutes);
                var overlap = approved.Any(x => !(e <= x.StartTimeUtc || s >= x.EndTimeUtc));
                result.Add(new SlotDto(s, e, !overlap));
            }
        }
        // giá cố định theo slot = PricePerHour * slotMinutes/60 (nếu có cấu hình)
        decimal? pricePerSlot = null;
        if (amenity?.PricePerHour != null) pricePerSlot = amenity.PricePerHour * (decimal)slotMinutes / 60m;
        return Ok(new { weekStartUtc = startWeek, slotMinutes, pricePerSlot, items = result });
    }

    public record BookDto(Guid AmenityId, DateTime StartTimeUtc, DateTime EndTimeUtc, decimal? Price,
        string? ContactPhone, string? Purpose, int? ParticipantCount, string? TransactionRef, bool? Paid, int? ReminderOffsetMinutes);
    [HttpPost]
    [Authorize] // Cho phép tất cả user đã đăng nhập, nhưng kiểm tra ResidentProfile bên trong
    public async Task<ActionResult<AmenityBooking>> Create(BookDto dto)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(uid)) return Unauthorized("Người dùng chưa đăng nhập.");

        // Kiểm tra quyền: Manager hoặc Resident đã verified
        var isManager = User.IsInRole("Manager");
        ResidentProfile? resident = null;
        if (!isManager)
        {
            resident = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (resident == null || !resident.IsVerifiedByBQL)
            {
                return Forbid("Chỉ cư dân đã được xác minh hoặc quản lý mới có thể đặt lịch tiện ích.");
            }
        }
        else
        {
            resident = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
        }

        if (dto.EndTimeUtc <= dto.StartTimeUtc) return BadRequest("Thời gian không hợp lệ.");

        var amenity = await _db.AmenityBookings.Select(x => x.Amenity).FirstOrDefaultAsync(a => a != null && a.Id == dto.AmenityId)
                      ?? await _db.Amenities.FirstOrDefaultAsync(a => a.Id == dto.AmenityId);
        if (amenity is null) return BadRequest("Tiện ích không tồn tại.");

        // Chặn trùng lịch: nếu đã có booking Approved trùng thời gian
        var overlap = await _db.AmenityBookings.AnyAsync(x => x.AmenityId == dto.AmenityId
            && x.Status == AmenityBookingStatus.Approved
            && !(dto.EndTimeUtc <= x.StartTimeUtc || dto.StartTimeUtc >= x.EndTimeUtc));
        if (overlap) return BadRequest("Khung giờ đã được đặt.");

        // Tính giá tự động nếu chưa truyền và tiện ích có PricePerHour
        decimal? price = dto.Price;
        if (price is null && amenity.PricePerHour.HasValue)
        {
            var hours = Math.Max(1, (int)Math.Ceiling((dto.EndTimeUtc - dto.StartTimeUtc).TotalHours));
            price = hours * amenity.PricePerHour.Value;
        }

        // Giới hạn số lượt/ ngày / tuần cho mỗi người dùng
        var dayStartUtc2 = new DateTime(dto.StartTimeUtc.Year, dto.StartTimeUtc.Month, dto.StartTimeUtc.Day, 0, 0, 0, DateTimeKind.Utc);
        // tính Monday của tuần hiện tại
        var dow = (int)dayStartUtc2.DayOfWeek; // Sunday=0
        var offsetToMonday = dow == 0 ? -6 : (1 - dow);
        var weekStartUtc2 = dayStartUtc2.AddDays(offsetToMonday);
        var maxPerDay = amenity.MaxPerDay ?? 2;   // fallback mặc định
        var maxPerWeek = amenity.MaxPerWeek ?? 5; // fallback mặc định

        if (maxPerDay > 0)
        {
            var countDay = await _db.AmenityBookings.CountAsync(x =>
                x.UserId == uid &&
                x.AmenityId == dto.AmenityId &&
                x.StartTimeUtc >= dayStartUtc2 &&
                x.StartTimeUtc < dayStartUtc2.AddDays(1));

            if (countDay >= maxPerDay)
                return BadRequest($"Vượt quá số lượt đặt trong ngày (tối đa {maxPerDay}).");
        }

        if (maxPerWeek > 0)
        {
            var countWeek = await _db.AmenityBookings.CountAsync(x =>
                x.UserId == uid &&
                x.AmenityId == dto.AmenityId &&
                x.StartTimeUtc >= weekStartUtc2 &&
                x.StartTimeUtc < weekStartUtc2.AddDays(7));

            if (countWeek >= maxPerWeek)
                return BadRequest($"Vượt quá số lượt đặt trong tuần (tối đa {maxPerWeek}).");
        }

        // Transaction để tránh xung đột đặt trùng phút chót
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var conflict = await _db.AmenityBookings.AnyAsync(x => x.AmenityId == dto.AmenityId
            && x.Status == AmenityBookingStatus.Approved
            && !(dto.EndTimeUtc <= x.StartTimeUtc || dto.StartTimeUtc >= x.EndTimeUtc));
        if (conflict) { await tx.RollbackAsync(); return Conflict("Vừa có người đặt trước bạn ở khung giờ này. Vui lòng chọn giờ khác."); }

        var reminderOffset = dto.ReminderOffsetMinutes.HasValue && dto.ReminderOffsetMinutes.Value > 0
            ? dto.ReminderOffsetMinutes.Value
            : 60;

        var b = new AmenityBooking { AmenityId = dto.AmenityId, UserId = uid, StartTimeUtc = dto.StartTimeUtc, EndTimeUtc = dto.EndTimeUtc, Price = price,
            ContactPhone = dto.ContactPhone, Purpose = dto.Purpose, ParticipantCount = dto.ParticipantCount,
            PaymentStatus = (dto.Paid == true) ? PaymentStatus.Success : PaymentStatus.Pending, TransactionRef = dto.TransactionRef,
            ReminderOffsetMinutes = reminderOffset };
        
        // Logic duyệt: Nếu cần duyệt thủ công → luôn Pending; Ngược lại nếu cho phép đặt và không có phí → Approved
        if (amenity.RequireManualApproval)
        {
            b.Status = AmenityBookingStatus.Pending; // Luôn chờ duyệt thủ công
        }
        else if (amenity.AllowBooking && (price is null || price == 0))
        {
            b.Status = AmenityBookingStatus.Approved; // Tự động duyệt
        }
        else
        {
            b.Status = AmenityBookingStatus.Pending; // Mặc định chờ duyệt
        }
        _db.AmenityBookings.Add(b);

        Invoice? invoice = null;
        if (price.HasValue && price.Value > 0 && resident != null)
        {
            invoice = new Invoice
            {
                ApartmentId = resident.ApartmentId,
                UserId = uid,
                Month = dto.StartTimeUtc.Month,
                Year = dto.StartTimeUtc.Year,
                PeriodStart = dto.StartTimeUtc,
                PeriodEnd = dto.EndTimeUtc,
                DueDate = dto.StartTimeUtc.Date,
                Status = InvoiceStatus.Unpaid,
                Type = InvoiceType.Service,
                Lines = new List<InvoiceLine>
                {
                    new InvoiceLine
                    {
                        FeeName = amenity.Name ?? "Tiện ích",
                        Description = $"Đặt tiện ích {amenity.Name} ({dto.StartTimeUtc:dd/MM HH:mm} - {dto.EndTimeUtc:HH:mm})",
                        Quantity = 1,
                        UnitPrice = price.Value,
                        Amount = price.Value
                    }
                },
                TotalAmount = price.Value
            };
            _db.Invoices.Add(invoice);
        }

        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        // Tự động tạo QR PayOS nếu có invoice
        string? qrData = null;
        Guid? paymentId = null;
        if (invoice != null && invoice.TotalAmount > 0)
        {
            try
            {
                // 0) Đánh dấu các payment cũ của invoice này là Failed (nếu có) để đảm bảo chỉ có payment mới
                var oldPayments = await _db.Payments
                    .Where(p => p.InvoiceId == invoice.Id && p.Status == PaymentStatus.Pending)
                    .ToListAsync();
                if (oldPayments.Any())
                {
                    _logger.LogInformation("Đánh dấu {Count} payment cũ của invoice {InvoiceId} là Failed để tạo payment mới", oldPayments.Count, invoice.Id);
                    foreach (var oldPayment in oldPayments)
                    {
                        oldPayment.Status = PaymentStatus.Failed;
                    }
                    await _db.SaveChangesAsync();
                }

                // 1) Tạo Payment mới
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
                var orderCode = (int)(DateTimeOffset.UtcNow.ToUnixTimeSeconds() % int.MaxValue);
                payment.TransactionCode = orderCode.ToString();

                var rawDescription = $"AMENITY {amenity.Name ?? "TIENICH"}";
                var description = BuildAmenityPayOsDescription(rawDescription);
                var amountInt = ConvertToPayOsAmount(payment.Amount);

                var cancelUrl = _config["PayOS:CancelUrl"]
                                ?? throw new InvalidOperationException("Thiếu PayOS CancelUrl trong appsettings.json");
                var returnUrl = _config["PayOS:ReturnUrl"]
                                ?? throw new InvalidOperationException("Thiếu PayOS ReturnUrl trong appsettings.json");

                var payOsRequest = new CreatePaymentLinkRequest
                {
                    OrderCode = orderCode,
                    Amount = amountInt,
                    Description = description,
                    CancelUrl = cancelUrl,
                    ReturnUrl = returnUrl,
                    Items = new List<PaymentLinkItem>
                    {
                        new PaymentLinkItem
                        {
                            Name = amenity.Name ?? "Amenity",
                            Quantity = 1,
                            Price = amountInt
                        }
                    }
                };

                var payOsResult = await _payOs.PaymentRequests.CreateAsync(payOsRequest);

                payment.TransactionRef = payOsResult.PaymentLinkId;
                await _db.SaveChangesAsync();

                qrData = payOsResult.CheckoutUrl;
                paymentId = payment.Id;

                if (!string.IsNullOrEmpty(dto.ContactPhone))
                {
                    try
                    {
                        var smsMessage = $"ICitizen: Đặt tiện ích {amenity.Name} thành công.\n" +
                                         $"Thời gian: {dto.StartTimeUtc:dd/MM/yyyy HH:mm} - {dto.EndTimeUtc:HH:mm}\n" +
                                         $"Số tiền: {invoice.TotalAmount:N0} đ\n" +
                                         $"Vui lòng quét QR PayOS để thanh toán: {qrData}";

                        await _smsService.SendSmsAsync(dto.ContactPhone, smsMessage);
                        _logger.LogInformation("Đã gửi SMS QR code cho booking {BookingId} đến {Phone}", b.Id, dto.ContactPhone);
                    }
                    catch (Exception smsEx)
                    {
                        _logger.LogWarning(smsEx, "Không thể gửi SMS QR code cho booking {BookingId}", b.Id);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể tạo QR PayOS cho booking {BookingId}", b.Id);
            }
        }

        // Thông báo cho cư dân và BQL
        try
        {
            var amenityName = amenity.Name ?? "tiện ích";
            var timeRange = $"{dto.StartTimeUtc:dd/MM/yyyy HH:mm} - {dto.EndTimeUtc:HH:mm}";
            await CreateUserNotificationAsync(uid,
                $"Đặt {amenityName}",
                $"Bạn đã đặt {amenityName} ({timeRange}). Trạng thái: {b.Status}",
                "AmenityBooking",
                "AmenityBookingCreated",
                b.Id);

            // Always fetch user info to display name instead of ID
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == uid);
            var userIdentifier = user?.FullName ?? user?.UserName ?? uid;
            
            await NotifyManagersAsync(
                $"Yêu cầu đặt {amenityName}",
                $"Cư dân {userIdentifier} đặt {amenityName} ({timeRange}). Trạng thái: {b.Status}",
                "AmenityBooking",  
                "AmenityBookingCreated",
                b.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không thể tạo user notification cho booking {BookingId}", b.Id);
        }

        return Ok(new
        {
            booking = new
            {
                b.Id,
                b.AmenityId,
                AmenityName = amenity.Name,
                b.StartTimeUtc,
                b.EndTimeUtc,
                b.Status,
                b.Price
            },
            invoiceId = invoice?.Id,
            amount = invoice?.TotalAmount ?? price ?? 0m,
            qrData = qrData,  // QR code data (payment URL)
            paymentId = paymentId  // Payment ID để tracking
        });
    }

    [HttpGet("{id}")]
    [Authorize]
    public async Task<ActionResult<AmenityBooking>> Get(Guid id)
        => await _db.AmenityBookings.Include(x => x.Amenity).FirstOrDefaultAsync(x => x.Id == id) is { } m ? m : NotFound();

    [HttpPut("{id}/approve")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Approve(Guid id)
    {
        var b = await _db.AmenityBookings
            .Include(x => x.Amenity)
            .FirstOrDefaultAsync(x => x.Id == id);
        if (b is null) return NotFound();

        // Nếu booking có giá, phải kiểm tra đã thanh toán chưa
        if (b.Price.HasValue && b.Price.Value > 0)
        {
            // Tìm invoice liên quan đến booking này
            var invoice = await _db.Invoices
                .Where(i => i.Type == InvoiceType.Service &&
                           i.UserId == b.UserId &&
                           i.PeriodStart.Date == b.StartTimeUtc.Date &&
                           i.PeriodEnd.Date == b.EndTimeUtc.Date &&
                           Math.Abs(i.TotalAmount - b.Price.Value) < 0.01m)
                .FirstOrDefaultAsync();

            if (invoice != null)
            {
                // Kiểm tra xem có payment thành công chưa
                var hasPaid = await _db.Payments
                    .AnyAsync(p => p.InvoiceId == invoice.Id && p.Status == PaymentStatus.Success);

                if (!hasPaid)
                {
                    return BadRequest(new { error = "Cư dân chưa thanh toán. Vui lòng yêu cầu thanh toán trước khi duyệt." });
                }

                // Cập nhật payment status của booking
                b.PaymentStatus = PaymentStatus.Success;
            }
            else
            {
                // Nếu không tìm thấy invoice, vẫn có thể approve nhưng cảnh báo
                // (trường hợp đặc biệt)
            }
        }

        b.Status = AmenityBookingStatus.Approved;
        await _db.SaveChangesAsync();

        if (_supportHub != null)
        {
            await CreateSupportTicketNotificationForBookingAsync(b, approved: true);
        }

        // thông báo realtime cho cư dân
        try
        {
            var amenityName = b.Amenity?.Name ?? "tiện ích";
            var msg = BuildAmenityNotificationMessage(b, b.Amenity, approved: true);
            await CreateUserNotificationAsync(b.UserId,
                $"Đặt {amenityName} đã được duyệt",
                msg,
                "AmenityBooking",
                "AmenityBookingApproved",
                b.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không thể gửi thông báo approve booking {BookingId}", b.Id);
        }

        return NoContent();
    }

    [HttpPut("{id}/reject")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Reject(Guid id)
    {
        var b = await _db.AmenityBookings
            .Include(x => x.Amenity)
            .FirstOrDefaultAsync(x => x.Id == id);
        if (b is null) return NotFound();
        b.Status = AmenityBookingStatus.Rejected;
        await _db.SaveChangesAsync();

        if (_supportHub != null)
        {
            await CreateSupportTicketNotificationForBookingAsync(b, approved: false);
        }

        try
        {
            var amenityName = b.Amenity?.Name ?? "tiện ích";
            var msg = BuildAmenityNotificationMessage(b, b.Amenity, approved: false);
            await CreateUserNotificationAsync(b.UserId,
                $"Đặt {amenityName} bị từ chối",
                msg,
                "AmenityBooking",
                "AmenityBookingRejected",
                b.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không thể gửi thông báo reject booking {BookingId}", b.Id);
        }

        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize]
    public async Task<IActionResult> Delete(Guid id)
    {
        var b = await _db.AmenityBookings.FindAsync(id);
        if (b is null) return NotFound();
        _db.AmenityBookings.Remove(b); await _db.SaveChangesAsync(); return NoContent();
    }

    private static SupportTicketStatus MapAmenityStatusToTicketStatus(AmenityBookingStatus status)
    {
        return status switch
        {
            AmenityBookingStatus.Approved => SupportTicketStatus.Resolved,
            AmenityBookingStatus.Rejected => SupportTicketStatus.Closed,
            AmenityBookingStatus.Pending => SupportTicketStatus.New,
            AmenityBookingStatus.Cancelled => SupportTicketStatus.Closed,
            AmenityBookingStatus.Completed => SupportTicketStatus.Resolved,
            _ => SupportTicketStatus.New
        };
    }

    private static string BuildAmenityNotificationMessage(AmenityBooking booking, Amenity? amenity, bool approved)
    {
        var amenityName = amenity?.Name ?? "tiện ích";
        var timeRange = $"{booking.StartTimeUtc:dd/MM/yyyy HH:mm} - {booking.EndTimeUtc:HH:mm}";
        var baseMsg = approved
            ? $"Yêu cầu đặt {amenityName} ({timeRange}) của bạn đã được phê duyệt."
            : $"Yêu cầu đặt {amenityName} ({timeRange}) của bạn đã bị từ chối.";

        return baseMsg;
    }

    private async Task CreateUserNotificationAsync(string userId, string title, string message, string type, string refType, Guid refId)
    {
        var n = new UserNotification
        {
            UserId = userId,
            Title = title,
            Message = message,
            Type = type,
            RefType = refType,
            RefId = refId
        };
        _db.UserNotifications.Add(n);
        await _db.SaveChangesAsync();

        var unread = await _db.UserNotifications.CountAsync(x => x.UserId == userId && x.ReadAtUtc == null && !x.IsDeleted);
        if (_notificationHub != null)
        {
            await _notificationHub.Clients.Group($"user-{userId}").SendAsync("userNotification", new
            {
                n.Id,
                n.Title,
                n.Message,
                n.Type,
                n.RefType,
                n.RefId,
                n.CreatedAtUtc,
                unreadCount = unread
            });
        }
    }

    private async Task NotifyManagersAsync(string title, string message, string type, string refType, Guid refId)
    {
        var managerIds = await _db.UserRoles.Where(r => r.RoleId == _db.Roles.FirstOrDefault(x => x.Name == "Manager")!.Id)
            .Select(r => r.UserId)
            .ToListAsync();

        foreach (var id in managerIds)
        {
            await CreateUserNotificationAsync(id, title, message, type, refType, refId);
        }

        if (_notificationHub != null)
        {
            await _notificationHub.Clients.Group("managers").SendAsync("userNotification", new
            {
                title,
                message,
                type,
                refType,
                refId
            });
        }
    }

    /// <summary>
    /// Tạo SupportTicket + message để cư dân nhận thông báo realtime sau khi BQL duyệt / từ chối đặt tiện ích.
    /// </summary>
    private async Task CreateSupportTicketNotificationForBookingAsync(AmenityBooking booking, bool approved)
    {
        try
        {
            var admin = await _userManager.GetUserAsync(User);
            if (admin == null || string.IsNullOrWhiteSpace(booking.UserId)) return;

            var amenity = await _db.Amenities.FirstOrDefaultAsync(a => a.Id == booking.AmenityId);

            var ticket = new SupportTicket
            {
                Title = $"Đặt tiện ích: {amenity?.Name ?? "Tiện ích"}",
                CreatedById = booking.UserId,
                ApartmentCode = null,
                Category = "Amenity",
                Status = MapAmenityStatusToTicketStatus(booking.Status)
            };

            var message = new SupportTicketMessage
            {
                Ticket = ticket,
                SenderId = admin.Id,
                Content = BuildAmenityNotificationMessage(booking, amenity, approved),
                IsFromStaff = true
            };

            _db.SupportTickets.Add(ticket);
            _db.SupportTicketMessages.Add(message);
            await _db.SaveChangesAsync();

            var ticketGroup = $"ticket-{ticket.Id}";

            await _supportHub!.Clients.Group(ticketGroup).SendAsync("TicketStatusChanged", new
            {
                ticketId = ticket.Id,
                status = ticket.Status.ToString(),
                createdById = ticket.CreatedById
            });

            await _supportHub.Clients.Group(StaffHubGroup).SendAsync("TicketStatusChanged", new
            {
                ticketId = ticket.Id,
                status = ticket.Status.ToString(),
                createdById = ticket.CreatedById
            });

            await _supportHub.Clients.Group(ticketGroup).SendAsync("TicketMessage", new
            {
                id = message.Id,
                ticketId = ticket.Id,
                senderId = message.SenderId,
                senderName = admin.FullName ?? admin.UserName ?? "Ban Quản Trị",
                content = message.Content,
                attachmentUrl = message.AttachmentUrl,
                createdAtUtc = message.CreatedAtUtc,
                isFromStaff = message.IsFromStaff
            });
        }
        catch
        {
            // tránh làm hỏng luồng chính nếu thông báo lỗi
        }
    }
}
