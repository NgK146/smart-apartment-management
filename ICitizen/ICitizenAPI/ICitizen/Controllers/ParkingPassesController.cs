using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ParkingPassesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly IInvoicePaymentService _invoicePaymentService;
    private readonly ILogger<ParkingPassesController> _logger;
    public ParkingPassesController(ApplicationDbContext db, IInvoicePaymentService invoicePaymentService, ILogger<ParkingPassesController> logger)
    {
        _db = db;
        _invoicePaymentService = invoicePaymentService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<PagedResult<object>> List([FromQuery] QueryParameters p, [FromQuery] Guid? vehicleId = null, [FromQuery] string? status = null)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        var q = _db.ParkingPasses
            .Include(pp => pp.Vehicle)
            .Include(pp => pp.ParkingPlan)
            .AsQueryable();
        
        // Resident chỉ xem vé của mình
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile != null)
            {
                var vehicleIds = await _db.Vehicles
                    .Where(v => v.ResidentProfileId == profile.Id)
                    .Select(v => v.Id)
                    .ToListAsync();
                q = q.Where(pp => vehicleIds.Contains(pp.VehicleId));
            }
            else
            {
                return new PagedResult<object>(Array.Empty<object>(), 0, p.Page, p.PageSize);
            }
        }
        
        if (vehicleId.HasValue) q = q.Where(pp => pp.VehicleId == vehicleId.Value);
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(pp => pp.Status == status);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(pp => pp.PassCode.Contains(p.Search) || 
                             (pp.Vehicle != null && pp.Vehicle.LicensePlate.Contains(p.Search)));
        
        var result = await q.OrderByDescending(x => x.CreatedAtUtc).ToPagedResultAsync(p.Page, p.PageSize);

        var dtoItems = result.Items.Select(MapParkingPass).ToList();
        return new PagedResult<object>(dtoItems, result.Total, result.Page, result.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<object>> Get(Guid id)
    {
        var pass = await _db.ParkingPasses
            .Include(pp => pp.Vehicle)
            .Include(pp => pp.ParkingPlan)
            .FirstOrDefaultAsync(pp => pp.Id == id);
        if (pass == null) return NotFound();
        
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || pass.Vehicle?.ResidentProfileId != profile.Id)
                return Forbid();
        }
        
        return Ok(MapParkingPass(pass));
    }

    // Cư dân: Đăng ký mua vé
    [HttpPost("register")]
    public async Task<ActionResult<object>> Register([FromBody] RegisterPassRequest request)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (uid == null) return Unauthorized();
        
        // Kiểm tra xe có tồn tại và đã được duyệt
        var vehicle = await _db.Vehicles
            .Include(v => v.ResidentProfile)
            .FirstOrDefaultAsync(v => v.Id == request.VehicleId);
        if (vehicle == null) return NotFound("Không tìm thấy xe");
        
        if (vehicle.Status != "Approved")
            return BadRequest("Xe chưa được duyệt. Vui lòng chờ Admin duyệt trước khi mua vé.");
        
        // Kiểm tra quyền sở hữu (nếu không phải Manager)
        var isManager = User.IsInRole("Manager");
        if (!isManager)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || vehicle.ResidentProfileId != profile.Id)
                return Forbid();
        }
        
        // Kiểm tra gói vé
        var plan = await _db.ParkingPlans.FindAsync(request.ParkingPlanId);
        if (plan == null) return NotFound("Không tìm thấy gói vé");
        if (!plan.IsActive) return BadRequest("Gói vé đã bị tắt");
        if (plan.VehicleType != vehicle.VehicleType)
            return BadRequest("Gói vé không phù hợp với loại xe");
        
        // Tính toán ngày hết hạn
        var validTo = request.ValidFrom.AddDays(plan.DurationInDays);
        
        // Tạo mã vé duy nhất
        var passCode = GeneratePassCode();
        
        // Tạo vé
        var pass = new ParkingPass
        {
            VehicleId = request.VehicleId,
            ParkingPlanId = request.ParkingPlanId,
            PassCode = passCode,
            ValidFrom = request.ValidFrom,
            ValidTo = validTo,
            Status = "PendingPayment", // Chờ thanh toán
        };
        
        // Tạo hóa đơn
        var invoice = new Invoice
        {
            ApartmentId = vehicle.ResidentProfile?.ApartmentId ?? Guid.Empty,
            UserId = uid,
            PeriodStart = request.ValidFrom,
            PeriodEnd = validTo,
            Status = InvoiceStatus.Unpaid,
            TotalAmount = plan.Price,
        };
        
        invoice.Lines.Add(new InvoiceLine
        {
            Description = $"Vé xe: {plan.Name} - {vehicle.LicensePlate}",
            Quantity = 1,
            UnitPrice = plan.Price,
            Amount = plan.Price,
        });
        
        _db.Invoices.Add(invoice);
        await _db.SaveChangesAsync();

        if (invoice.TotalAmount > 0)
        {
            try
            {
                await _invoicePaymentService.EnsureVnPayPaymentAsync(invoice, HttpContext, $"Thanh toán vé xe {plan.Name}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể tạo QR cho vé xe {PassCode}", passCode);
            }
        }
        
        // Liên kết hóa đơn với vé
        pass.InvoiceId = invoice.Id;
        _db.ParkingPasses.Add(pass);
        await _db.SaveChangesAsync();
        
        var savedPass = await _db.ParkingPasses
            .Include(pp => pp.Vehicle)
            .Include(pp => pp.ParkingPlan)
            .FirstOrDefaultAsync(pp => pp.Id == pass.Id);
        
        return Ok(MapParkingPass(savedPass ?? pass));
    }

    // Admin: Hủy vé
    [HttpPost("{id}/revoke")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Revoke(Guid id, [FromBody] RevokePassRequest request)
    {
        var pass = await _db.ParkingPasses.FindAsync(id);
        if (pass == null) return NotFound();
        
        pass.Status = "Revoked";
        pass.RevocationReason = request.Reason;
        await _db.SaveChangesAsync();
        return Ok(pass);
    }

    private string GeneratePassCode()
    {
        // Tạo mã vé duy nhất dạng: VEH-{8 ký tự ngẫu nhiên}
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var random = new Random();
        string code;
        int attempts = 0;
        do
        {
            var sb = new StringBuilder("VEH-");
            for (int i = 0; i < 8; i++)
            {
                sb.Append(chars[random.Next(chars.Length)]);
            }
            code = sb.ToString();
            attempts++;
        } while (_db.ParkingPasses.Any(pp => pp.PassCode == code) && attempts < 10);
        
        return code;
    }

    private static object MapParkingPass(ParkingPass pass)
    {
        return new
        {
            id = pass.Id,
            vehicleId = pass.VehicleId,
            vehicle = pass.Vehicle == null ? null : new
            {
                id = pass.Vehicle.Id,
                licensePlate = pass.Vehicle.LicensePlate,
                vehicleType = pass.Vehicle.VehicleType,
                brand = pass.Vehicle.Brand,
                model = pass.Vehicle.Model,
                color = pass.Vehicle.Color
            },
            parkingPlanId = pass.ParkingPlanId,
            parkingPlan = pass.ParkingPlan == null ? null : new
            {
                id = pass.ParkingPlan.Id,
                name = pass.ParkingPlan.Name,
                description = pass.ParkingPlan.Description,
                vehicleType = pass.ParkingPlan.VehicleType,
                price = pass.ParkingPlan.Price,
                durationInDays = pass.ParkingPlan.DurationInDays
            },
            passCode = pass.PassCode,
            validFrom = pass.ValidFrom,
            validTo = pass.ValidTo,
            status = pass.Status,
            invoiceId = pass.InvoiceId,
            activatedAt = pass.ActivatedAt,
            revocationReason = pass.RevocationReason,
            createdAtUtc = pass.CreatedAtUtc,
            updatedAtUtc = pass.UpdatedAtUtc
        };
    }
}

public class RegisterPassRequest
{
    public Guid VehicleId { get; set; }
    public Guid ParkingPlanId { get; set; }
    public DateTime ValidFrom { get; set; }
}

public class RevokePassRequest
{
    public string Reason { get; set; } = string.Empty;
}

