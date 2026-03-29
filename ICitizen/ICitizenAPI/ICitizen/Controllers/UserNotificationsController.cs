using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UserNotificationsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly IHubContext<ICitizen.Hubs.NotificationHub>? _hub;

    public UserNotificationsController(ApplicationDbContext db, IHubContext<ICitizen.Hubs.NotificationHub>? hub = null)
    {
        _db = db;
        _hub = hub;
    }

    private string? CurrentUserId => User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

    [HttpGet]
    [Authorize]
    public async Task<IActionResult> List([FromQuery] int page = 1, [FromQuery] int pageSize = 20, [FromQuery] bool unreadOnly = false)
    {
        var uid = CurrentUserId;
        if (string.IsNullOrEmpty(uid)) return Unauthorized();

        if (page <= 0) page = 1;
        if (pageSize <= 0 || pageSize > 100) pageSize = 20;

        var q = _db.UserNotifications.Where(x => x.UserId == uid && !x.IsDeleted);
        if (unreadOnly) q = q.Where(x => x.ReadAtUtc == null);

        var total = await q.CountAsync();
        var items = await q
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new
            {
                x.Id,
                x.Title,
                x.Message,
                x.Type,
                x.RefType,
                x.RefId,
                x.CreatedAtUtc,
                x.ReadAtUtc
            }).ToListAsync();

        var unreadCount = await _db.UserNotifications.CountAsync(x => x.UserId == uid && x.ReadAtUtc == null && !x.IsDeleted);

        return Ok(new
        {
            items,
            total,
            page,
            pageSize,
            unreadCount
        });
    }

    [HttpPatch("{id}/read")]
    [Authorize]
    public async Task<IActionResult> MarkRead(Guid id)
    {
        var uid = CurrentUserId;
        if (string.IsNullOrEmpty(uid)) return Unauthorized();

        var n = await _db.UserNotifications.FirstOrDefaultAsync(x => x.Id == id && x.UserId == uid);
        if (n is null) return NotFound();
        if (n.ReadAtUtc == null)
        {
            n.ReadAtUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        return NoContent();
    }

    [HttpPatch("read-all")]
    [Authorize]
    public async Task<IActionResult> MarkAllRead()
    {
        var uid = CurrentUserId;
        if (string.IsNullOrEmpty(uid)) return Unauthorized();

        try
        {
            var now = DateTime.UtcNow;
            var items = await _db.UserNotifications
                .Where(x => x.UserId == uid && x.ReadAtUtc == null && !x.IsDeleted)
                .ToListAsync();

            if (items.Count > 0)
            {
                foreach (var n in items)
                {
                    n.ReadAtUtc = now;
                }
                await _db.SaveChangesAsync();
            }
            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Không thể đánh dấu tất cả đã đọc", message = ex.Message });
        }
    }

    // Helper to emit realtime updates
    public static async Task PushAsync(IHubContext<ICitizen.Hubs.NotificationHub>? hub, string userId, object payload)
    {
        if (hub == null) return;
        await hub.Clients.Group($"user-{userId}").SendAsync("userNotification", payload);
    }
}

