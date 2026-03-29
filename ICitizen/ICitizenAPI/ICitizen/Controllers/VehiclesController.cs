using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class VehiclesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly ILogger<VehiclesController> _logger;
    private readonly UserManager<AppUser> _userManager;
    private readonly IHubContext<SupportHub>? _supportHub;

    private const string StaffHubGroup = "support-staff";
    
    public VehiclesController(
        ApplicationDbContext db,
        ILogger<VehiclesController> logger,
        UserManager<AppUser> userManager,
        IHubContext<SupportHub>? supportHub = null)
    {
        _db = db;
        _logger = logger;
        _userManager = userManager;
        _supportHub = supportHub;
    }

    // Manager xem tất cả; Resident xem của mình
    [HttpGet]
    public async Task<PagedResult<Vehicle>> List([FromQuery] QueryParameters p, [FromQuery] Guid? residentProfileId = null, [FromQuery] string? status = null)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        var q = _db.Vehicles.Include(v => v.ResidentProfile).AsQueryable();
        
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile != null) q = q.Where(v => v.ResidentProfileId == profile.Id);
        }
        
        if (residentProfileId.HasValue) q = q.Where(v => v.ResidentProfileId == residentProfileId.Value);
        if (!string.IsNullOrWhiteSpace(status)) q = q.Where(v => v.Status == status);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(v => v.LicensePlate.Contains(p.Search) || (v.VehicleType ?? "").Contains(p.Search));
        
        return await q.OrderByDescending(x => x.CreatedAtUtc).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Vehicle>> Get(Guid id)
    {
        var vehicle = await _db.Vehicles.Include(v => v.ResidentProfile).FirstOrDefaultAsync(v => v.Id == id);
        if (vehicle is null) return NotFound();
        
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || vehicle.ResidentProfileId != profile.Id) return Forbid();
        }
        
        return vehicle;
    }

    [HttpPost]
    [Authorize] // Cho phép tất cả user đã đăng nhập
    public async Task<IActionResult> Create(Vehicle m)
    {
        try
        {
            // Validation
            if (m == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            if (string.IsNullOrWhiteSpace(m.LicensePlate))
                return BadRequest(new { error = "Biển số xe là bắt buộc" });
            
            // Kiểm tra biển số đã tồn tại chưa
            var existingVehicle = await _db.Vehicles
                .FirstOrDefaultAsync(v => v.LicensePlate == m.LicensePlate);
            if (existingVehicle != null)
                return Conflict(new { error = "Biển số xe đã tồn tại" });
            
            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (uid == null) return Unauthorized();
            
            var isManager = User.IsInRole("Manager");
            if (!isManager)
            {
                var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
                if (profile == null) return BadRequest(new { error = "Chưa có hồ sơ cư dân" });
                m.ResidentProfileId = profile.Id;
                // Cư dân tạo xe mặc định là Pending
                m.Status = "Pending";
            }
            else
            {
                // Manager có thể tạo với status khác
                if (string.IsNullOrWhiteSpace(m.Status))
                    m.Status = "Pending";
                
                // Nếu Manager chỉ định ResidentProfileId, kiểm tra tồn tại
                if (m.ResidentProfileId != Guid.Empty)
                {
                    var profileExists = await _db.ResidentProfiles.AnyAsync(r => r.Id == m.ResidentProfileId);
                    if (!profileExists)
                        return BadRequest(new { error = "Hồ sơ cư dân không tồn tại" });
                }
            }
            
            _db.Vehicles.Add(m);
            await _db.SaveChangesAsync();
            return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi tạo thông tin xe", _logger);
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Resident,Manager")]
    public async Task<IActionResult> Update(Guid id, Vehicle m)
    {
        try
        {
            if (m == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            var dbm = await _db.Vehicles.FindAsync(id);
            if (dbm is null) return NotFound(new { error = "Không tìm thấy thông tin xe" });
            
            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            var isManager = User.IsInRole("Manager");
            if (!isManager && uid != null)
            {
                var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
                if (profile == null || dbm.ResidentProfileId != profile.Id) return Forbid();
            }
            
            // Validation
            if (string.IsNullOrWhiteSpace(m.LicensePlate))
                return BadRequest(new { error = "Biển số xe là bắt buộc" });
            
            // Kiểm tra biển số trùng (trừ chính nó)
            var existingVehicle = await _db.Vehicles
                .FirstOrDefaultAsync(v => v.LicensePlate == m.LicensePlate && v.Id != id);
            if (existingVehicle != null)
                return Conflict(new { error = "Biển số xe đã được sử dụng bởi xe khác" });
            
            dbm.LicensePlate = m.LicensePlate;
            dbm.VehicleType = m.VehicleType;
            dbm.Brand = m.Brand;
            dbm.Model = m.Model;
            dbm.Color = m.Color;
            dbm.IsActive = m.IsActive;
            // Chỉ cho phép cập nhật status khi đang ở trạng thái Pending
            if (dbm.Status == "Pending" && !string.IsNullOrWhiteSpace(m.Status))
            {
                dbm.Status = m.Status;
            }
            await _db.SaveChangesAsync();
            return NoContent();
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi cập nhật thông tin xe", _logger);
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Resident,Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.Vehicles.FindAsync(id);
        if (m is null) return NotFound();
        
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || m.ResidentProfileId != profile.Id) return Forbid();
        }
        
        _db.Vehicles.Remove(m);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    // Admin: Duyệt xe
    [HttpPost("{id}/approve")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Approve(Guid id)
    {
        var vehicle = await _db.Vehicles.FindAsync(id);
        if (vehicle == null) return NotFound();
        
        vehicle.Status = "Approved";
        vehicle.IsActive = true;
        vehicle.RejectionReason = null;
        await _db.SaveChangesAsync();

        // Thông báo qua module Hỗ trợ / Ticket cho cư dân
        if (_supportHub != null)
        {
            await CreateSupportTicketNotificationForVehicleAsync(vehicle, approved: true);
        }

        return Ok(vehicle);
    }

    // Admin: Từ chối xe
    [HttpPost("{id}/reject")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Reject(Guid id, [FromBody] RejectVehicleRequest request)
    {
        try
        {
            if (request == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            var vehicle = await _db.Vehicles.FindAsync(id);
            if (vehicle == null) return NotFound(new { error = "Không tìm thấy thông tin xe" });
            
            vehicle.Status = "Rejected";
            vehicle.RejectionReason = request.Reason;
            await _db.SaveChangesAsync();

            // Thông báo qua module Hỗ trợ / Ticket cho cư dân
            if (_supportHub != null)
            {
                await CreateSupportTicketNotificationForVehicleAsync(vehicle, approved: false);
            }

            return Ok(vehicle);
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi từ chối xe", _logger);
        }
    }

    private static SupportTicketStatus MapVehicleStatusToTicketStatus(string status)
    {
        return status switch
        {
            "Approved" => SupportTicketStatus.Resolved,
            "Rejected" => SupportTicketStatus.Closed,
            "Pending" => SupportTicketStatus.New,
            _ => SupportTicketStatus.New
        };
    }

    private static string BuildVehicleNotificationMessage(Vehicle vehicle, bool approved)
    {
        var baseMsg = approved
            ? $"Yêu cầu đăng ký xe {vehicle.LicensePlate} của bạn đã được phê duyệt."
            : $"Yêu cầu đăng ký xe {vehicle.LicensePlate} của bạn đã bị từ chối.";

        if (!approved && !string.IsNullOrWhiteSpace(vehicle.RejectionReason))
        {
            baseMsg += $" Lý do: {vehicle.RejectionReason}";
        }

        return baseMsg;
    }

    /// <summary>
    /// Tạo SupportTicket + message để cư dân nhận thông báo realtime sau khi BQL duyệt / từ chối xe.
    /// </summary>
    private async Task CreateSupportTicketNotificationForVehicleAsync(Vehicle vehicle, bool approved)
    {
        try
        {
            var admin = await _userManager.GetUserAsync(User);
            if (admin == null) return;

            // Tìm userId của cư dân sở hữu xe
            var profile = await _db.ResidentProfiles
                .Include(r => r.Apartment)
                .FirstOrDefaultAsync(r => r.Id == vehicle.ResidentProfileId);
            if (profile == null || string.IsNullOrWhiteSpace(profile.UserId)) return;

            var ticket = new SupportTicket
            {
                Title = $"Đăng ký xe: {vehicle.LicensePlate}",
                CreatedById = profile.UserId,
                ApartmentCode = profile.Apartment?.Code,
                Category = "Vehicle",
                Status = MapVehicleStatusToTicketStatus(vehicle.Status)
            };

            var message = new SupportTicketMessage
            {
                Ticket = ticket,
                SenderId = admin.Id,
                Content = BuildVehicleNotificationMessage(vehicle, approved),
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

public class RejectVehicleRequest
{
    public string Reason { get; set; } = string.Empty;
}


