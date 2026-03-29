using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using ICitizen.Hubs;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ConciergeController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<AppUser> _userManager;
    private readonly IHubContext<NotificationHub>? _notificationHub;

    public ConciergeController(ApplicationDbContext db, UserManager<AppUser> userManager, IHubContext<NotificationHub>? notificationHub = null)
    {
        _db = db;
        _userManager = userManager;
        _notificationHub = notificationHub;
    }

    /// <summary>
    /// Cư dân gửi yêu cầu concierge
    /// POST /api/Concierge/requests
    /// </summary>
    [HttpPost("requests")]
    public async Task<IActionResult> CreateRequest([FromBody] CreateConciergeRequestDto dto)
    {
        var me = await _userManager.GetUserAsync(User);
        if (me == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(dto.ServiceId))
            return BadRequest(new { error = "Vui lòng chọn loại dịch vụ." });

        var entity = new ConciergeRequest
        {
            ServiceId = dto.ServiceId,
            ServiceName = dto.ServiceName ?? string.Empty,
            UserId = me.Id,
            Notes = dto.Notes,
            ScheduledForUtc = dto.ScheduledForUtc,
            Status = ConciergeRequestStatus.Pending
        };

        _db.ConciergeRequests.Add(entity);
        await _db.SaveChangesAsync();

        // Thông báo cho BQL (group "managers")
        await NotifyManagersAsync(
            $"Yêu cầu concierge mới: {entity.ServiceName}",
            $"{me.FullName ?? me.UserName ?? "Cư dân"} vừa gửi yêu cầu concierge.",
            "ConciergeRequestCreated",
            entity.Id);

        // Thông báo xác nhận cho cư dân
        await NotifyUserAsync(
            me.Id,
            $"Đã gửi yêu cầu concierge: {entity.ServiceName}",
            "Yêu cầu của bạn đã được gửi. BQL sẽ xử lý sớm.",
            "ConciergeRequestCreated",
            entity.Id);

        return Ok(new
        {
            id = entity.Id,
            serviceId = entity.ServiceId,
            serviceName = entity.ServiceName,
            notes = entity.Notes,
            scheduledForUtc = entity.ScheduledForUtc,
            status = entity.Status.ToString(),
            createdAtUtc = entity.CreatedAtUtc
        });
    }

    /// <summary>
    /// Danh sách yêu cầu concierge của user hiện tại
    /// GET /api/Concierge/my-requests
    /// </summary>
    [HttpGet("my-requests")]
    public async Task<IActionResult> GetMyRequests([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var me = await _userManager.GetUserAsync(User);
        if (me == null) return Unauthorized();

        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var q = _db.ConciergeRequests
            .Where(x => x.UserId == me.Id)
            .OrderByDescending(x => x.CreatedAtUtc);

        var total = await q.CountAsync();
        var data = await q
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var items = data.Select(x => new
        {
            id = x.Id,
            serviceId = x.ServiceId,
            serviceName = x.ServiceName,
            notes = x.Notes,
            scheduledForUtc = x.ScheduledForUtc,
            status = x.Status.ToString(),
            createdAtUtc = x.CreatedAtUtc
        });

        return Ok(new { page, pageSize, total, items });
    }

    // Helpers (resident scope)
    private async Task NotifyManagersAsync(string title, string message, string refType, Guid refId)
    {
        try
        {
            var managerRoleId = await _db.Roles.Where(r => r.Name == "Manager").Select(r => r.Id).FirstOrDefaultAsync();
            if (managerRoleId == null) return;

            var managerIds = await _db.UserRoles.Where(ur => ur.RoleId == managerRoleId).Select(ur => ur.UserId).ToListAsync();
            foreach (var uid in managerIds)
            {
                _db.UserNotifications.Add(new UserNotification
                {
                    UserId = uid,
                    Title = title,
                    Message = message,
                    Type = "Concierge",
                    RefType = refType,
                    RefId = refId,
                    CreatedAtUtc = DateTime.UtcNow
                });
            }
            await _db.SaveChangesAsync();

            if (_notificationHub != null)
            {
                await _notificationHub.Clients.Group("managers").SendAsync("userNotification", new
                {
                    title,
                    message,
                    type = "Concierge",
                    refType,
                    refId
                });
            }
        }
        catch
        {
            // ignore
        }
    }

    private async Task NotifyUserAsync(string userId, string title, string message, string refType, Guid refId)
    {
        try
        {
            var n = new UserNotification
            {
                UserId = userId,
                Title = title,
                Message = message,
                Type = "Concierge",
                RefType = refType,
                RefId = refId,
                CreatedAtUtc = DateTime.UtcNow
            };
            _db.UserNotifications.Add(n);
            await _db.SaveChangesAsync();

            if (_notificationHub != null)
            {
                var unread = await _db.UserNotifications.CountAsync(x => x.UserId == userId && x.ReadAtUtc == null && !x.IsDeleted);
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
        catch
        {
        }
    }
}

public sealed class CreateConciergeRequestDto
{
    public string ServiceId { get; set; } = default!;
    public string? ServiceName { get; set; }
    public string? Notes { get; set; }
    public DateTime? ScheduledForUtc { get; set; }
}

// ===== ADMIN ENDPOINTS =====

[ApiController]
[Route("api/admin/Concierge")]
[Authorize(Roles = "Manager")]
public sealed class AdminConciergeController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<AppUser> _userManager;
    private readonly IHubContext<NotificationHub>? _notificationHub;

    public AdminConciergeController(ApplicationDbContext db, UserManager<AppUser> userManager, IHubContext<NotificationHub>? notificationHub = null)
    {
        _db = db;
        _userManager = userManager;
        _notificationHub = notificationHub;
    }

    /// <summary>
    /// Danh sách yêu cầu concierge của cư dân
    /// GET /api/admin/Concierge/requests
    /// </summary>
    [HttpGet("requests")]
    public async Task<IActionResult> List(
        [FromQuery] string? status,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var q = _db.ConciergeRequests.AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) &&
            Enum.TryParse<ConciergeRequestStatus>(status, true, out var st))
        {
            q = q.Where(x => x.Status == st);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            search = search.Trim().ToLower();
            q = q.Where(x =>
                (x.ServiceName != null && x.ServiceName.ToLower().Contains(search)) ||
                (x.Notes != null && x.Notes.ToLower().Contains(search)) ||
                x.ServiceId.ToLower().Contains(search));
        }

        var total = await q.CountAsync();

        var data = await q
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        // Load users để lấy tên
        var userIds = data.Select(x => x.UserId).Distinct().ToList();
        var users = await _userManager.Users
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u);

        var items = data.Select(x =>
        {
            users.TryGetValue(x.UserId, out var u);
            var name = u?.FullName ?? u?.UserName ?? string.Empty;
            return new
            {
                id = x.Id,
                serviceId = x.ServiceId,
                serviceName = x.ServiceName,
                notes = x.Notes,
                scheduledForUtc = x.ScheduledForUtc,
                status = x.Status.ToString(),
                createdAtUtc = x.CreatedAtUtc,
                userId = x.UserId,
                userName = name
            };
        });

        return Ok(new { page, pageSize, total, items });
    }

    /// <summary>
    /// Cập nhật trạng thái yêu cầu
    /// PUT /api/admin/Concierge/requests/{id}/status
    /// body: { "status": "InProgress" }
    /// </summary>
    [HttpPut("requests/{id:guid}/status")]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateConciergeRequestStatusDto dto)
    {
        if (!Enum.TryParse<ConciergeRequestStatus>(dto.Status, true, out var newStatus))
            return BadRequest(new { error = "Trạng thái không hợp lệ." });

        var entity = await _db.ConciergeRequests.FirstOrDefaultAsync(x => x.Id == id);
        if (entity == null) return NotFound(new { error = "Không tìm thấy yêu cầu." });

        entity.Status = newStatus;
        await _db.SaveChangesAsync();

        // Gửi thông báo cho cư dân
        if (!string.IsNullOrEmpty(entity.UserId))
        {
            var message = $"Yêu cầu concierge \"{entity.ServiceName}\" của bạn đã được cập nhật: {entity.Status}.";
            await NotifyUserAsync(entity.UserId,
                $"Yêu cầu concierge: {entity.ServiceName}",
                message,
                "ConciergeRequestStatusChanged",
                entity.Id);
        }

        return Ok(new
        {
            id = entity.Id,
            status = entity.Status.ToString()
        });
    }

    // Helpers for resident scope
    private async Task NotifyManagersAsync(string title, string message, string refType, Guid refId)
    {
        try
        {
            var managerRoleId = await _db.Roles.Where(r => r.Name == "Manager").Select(r => r.Id).FirstOrDefaultAsync();
            if (managerRoleId == null) return;

            var managerIds = await _db.UserRoles.Where(ur => ur.RoleId == managerRoleId).Select(ur => ur.UserId).ToListAsync();
            foreach (var uid in managerIds)
            {
                _db.UserNotifications.Add(new UserNotification
                {
                    UserId = uid,
                    Title = title,
                    Message = message,
                    Type = "Concierge",
                    RefType = refType,
                    RefId = refId,
                    CreatedAtUtc = DateTime.UtcNow
                });
            }
            await _db.SaveChangesAsync();

            if (_notificationHub != null)
            {
                await _notificationHub.Clients.Group("managers").SendAsync("userNotification", new
                {
                    title,
                    message,
                    type = "Concierge",
                    refType,
                    refId
                });
            }
        }
        catch
        {
            // ignore
        }
    }

    private async Task NotifyUserAsync(string userId, string title, string message, string refType, Guid refId)
    {
        try
        {
            var n = new UserNotification
            {
                UserId = userId,
                Title = title,
                Message = message,
                Type = "Concierge",
                RefType = refType,
                RefId = refId,
                CreatedAtUtc = DateTime.UtcNow
            };
            _db.UserNotifications.Add(n);
            await _db.SaveChangesAsync();

            if (_notificationHub != null)
            {
                var unread = await _db.UserNotifications.CountAsync(x => x.UserId == userId && x.ReadAtUtc == null && !x.IsDeleted);
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
        catch
        {
        }
    }
}

public sealed class UpdateConciergeRequestStatusDto
{
    public string Status { get; set; } = default!;
}



