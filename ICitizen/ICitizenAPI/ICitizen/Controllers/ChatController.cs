using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using ICitizen.Common;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/support")]
[Authorize]
public class SupportController : ControllerBase
{
	private readonly ApplicationDbContext _db;
    private readonly ILogger<SupportController> _logger;
    private readonly IHubContext<SupportHub>? _hub;

    private const string StaffHubGroup = "support-staff";

    public SupportController(ApplicationDbContext db, ILogger<SupportController> logger, IHubContext<SupportHub>? hub = null)
	{
		_db = db;
		_logger = logger;
        _hub = hub;
	}

	private string GetUserId() =>
		User.FindFirstValue(ClaimTypes.NameIdentifier) ?? throw new UnauthorizedAccessException();

    private bool IsManagerLike() =>
        User.IsInRole("Manager") || User.IsInRole("Security");

    private async Task<Dictionary<string, string>> GetUserNamesAsync(IEnumerable<string> userIds)
    {
        var ids = userIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList();
        if (!ids.Any()) return new Dictionary<string, string>();

        return await _db.Users
            .Where(u => ids.Contains(u.Id))
            .Select(u => new { u.Id, Name = u.FullName ?? u.UserName ?? u.Email ?? u.Id })
            .ToDictionaryAsync(x => x.Id, x => x.Name);
    }

    [HttpGet("tickets")]
    public async Task<ActionResult<IEnumerable<SupportTicketSummaryDto>>> GetTickets(
        [FromQuery] SupportTicketFilter filter)
	{
		try
		{
			var me = GetUserId();
            var isManager = IsManagerLike();

            var query = _db.SupportTickets
                .Include(t => t.Messages)
				.AsNoTracking()
                .AsQueryable();

            if (!isManager)
            {
                query = query.Where(t => t.CreatedById == me);
            }
            else if (!string.IsNullOrWhiteSpace(filter.CreatedById))
            {
                query = query.Where(t => t.CreatedById == filter.CreatedById);
            }

            if (!string.IsNullOrWhiteSpace(filter.Status))
            {
                if (Enum.TryParse<SupportTicketStatus>(filter.Status, true, out var status))
                {
                    query = query.Where(t => t.Status == status);
                }
            }

            if (!string.IsNullOrWhiteSpace(filter.AssignedToId))
            {
                query = query.Where(t => t.AssignedToId == filter.AssignedToId);
            }

            if (!string.IsNullOrWhiteSpace(filter.ApartmentCode))
            {
                query = query.Where(t => t.ApartmentCode == filter.ApartmentCode);
            }

            if (!string.IsNullOrWhiteSpace(filter.Search))
            {
                var keyword = filter.Search.Trim().ToLower();
                query = query.Where(t =>
                    t.Title.ToLower().Contains(keyword) ||
                    (t.ApartmentCode ?? string.Empty).ToLower().Contains(keyword));
            }

            var tickets = await query
                .OrderByDescending(t => t.UpdatedAtUtc ?? t.CreatedAtUtc)
                .ThenByDescending(t => t.CreatedAtUtc)
                .ToListAsync();

            var userIds = tickets
                .SelectMany(t => new[] { t.CreatedById, t.AssignedToId ?? string.Empty })
                .Where(id => !string.IsNullOrWhiteSpace(id));

            var userNames = await GetUserNamesAsync(userIds);

            var lastMessages = await _db.SupportTicketMessages
                .Where(m => tickets.Select(t => t.Id).Contains(m.TicketId))
                .GroupBy(m => m.TicketId)
                .Select(g => g.OrderByDescending(m => m.CreatedAtUtc).First())
				.ToListAsync();

            var summaries = tickets.Select(t =>
            {
                var lastMessage = lastMessages.FirstOrDefault(m => m.TicketId == t.Id);
                return new SupportTicketSummaryDto
                {
                    TicketId = t.Id,
                    Title = t.Title,
                    CreatedById = t.CreatedById,
                    CreatedByName = userNames.TryGetValue(t.CreatedById, out var cn) ? cn : string.Empty,
                    ApartmentCode = t.ApartmentCode,
                    Status = t.Status,
                    CreatedAtUtc = t.CreatedAtUtc,
                    UpdatedAtUtc = t.UpdatedAtUtc,
                    AssignedToId = t.AssignedToId,
                    AssignedToName = !string.IsNullOrWhiteSpace(t.AssignedToId) && userNames.TryGetValue(t.AssignedToId, out var an) ? an : null,
                    LastMessagePreview = lastMessage?.Content,
                    LastMessageAtUtc = lastMessage?.CreatedAtUtc
                };
            }).ToList();

            return Ok(summaries);
		}
		catch (Exception ex)
		{
            _logger.LogError(ex, "GetTickets failed");
            return StatusCode(500, new { error = "Không thể tải danh sách yêu cầu hỗ trợ", message = ex.Message });
		}
	}

    [HttpGet("tickets/{ticketId:guid}")]
    public async Task<ActionResult<SupportTicketDetailDto>> GetTicketDetail(Guid ticketId)
	{
		try
		{
			var me = GetUserId();
            var isManager = IsManagerLike();

            var ticket = await _db.SupportTickets
                .Include(t => t.Messages)
                .FirstOrDefaultAsync(t => t.Id == ticketId);

            if (ticket == null) return NotFound();
            if (!isManager && ticket.CreatedById != me)
            {
                return Forbid();
            }

            var userIds = ticket.Messages.Select(m => m.SenderId).Append(ticket.CreatedById);
            if (!string.IsNullOrWhiteSpace(ticket.AssignedToId))
            {
                userIds = userIds.Append(ticket.AssignedToId);
            }
            var userNames = await GetUserNamesAsync(userIds);

            var dto = new SupportTicketDetailDto
            {
                TicketId = ticket.Id,
                Title = ticket.Title,
                CreatedById = ticket.CreatedById,
                CreatedByName = userNames.TryGetValue(ticket.CreatedById, out var creator) ? creator : string.Empty,
                ApartmentCode = ticket.ApartmentCode,
                Category = ticket.Category,
                Status = ticket.Status,
                AssignedToId = ticket.AssignedToId,
                AssignedToName = ticket.AssignedToId != null && userNames.TryGetValue(ticket.AssignedToId, out var assigned) ? assigned : null,
                CreatedAtUtc = ticket.CreatedAtUtc,
                UpdatedAtUtc = ticket.UpdatedAtUtc,
                Messages = ticket.Messages
                    .OrderBy(m => m.CreatedAtUtc)
                    .Select(m => new SupportTicketMessageDto
				{
					Id = m.Id,
                        TicketId = m.TicketId,
					SenderId = m.SenderId,
                        SenderName = userNames.TryGetValue(m.SenderId, out var name) ? name : string.Empty,
					Content = m.Content,
                        AttachmentUrl = m.AttachmentUrl,
                        CreatedAtUtc = m.CreatedAtUtc,
                        IsFromStaff = m.IsFromStaff
                    })
                    .ToList()
            };

            return Ok(dto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetTicketDetail failed for {TicketId}", ticketId);
            return StatusCode(500, new { error = "Không thể tải chi tiết yêu cầu hỗ trợ", message = ex.Message });
        }
    }

    [HttpPost("tickets")]
    public async Task<ActionResult<SupportTicketDetailDto>> CreateTicket([FromBody] CreateTicketRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest("Vui lòng nhập tiêu đề yêu cầu.");
        }
        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest("Vui lòng mô tả vấn đề.");
        }

        try
        {
            var userId = GetUserId();

            string? apartmentCode = null;
            var profile = await _db.ResidentProfiles
                .Include(r => r.Apartment)
                .FirstOrDefaultAsync(r => r.UserId == userId && r.IsVerifiedByBQL);
            if (profile?.Apartment != null)
            {
                apartmentCode = profile.Apartment.Code;
            }

            var ticket = new SupportTicket
            {
                Title = request.Title.Trim(),
                CreatedById = userId,
                Category = request.Category?.Trim(),
                ApartmentCode = apartmentCode,
                Status = SupportTicketStatus.New
            };

            _db.SupportTickets.Add(ticket);

            var message = new SupportTicketMessage
            {
                Ticket = ticket,
                SenderId = userId,
                Content = request.Content.Trim(),
                AttachmentUrl = request.AttachmentUrl,
                IsFromStaff = false
            };
            _db.SupportTicketMessages.Add(message);

            await _db.SaveChangesAsync();

            var summary = new SupportTicketSummaryDto
            {
                TicketId = ticket.Id,
                Title = ticket.Title,
                CreatedById = ticket.CreatedById,
                CreatedByName = (await GetUserNamesAsync(new[] { ticket.CreatedById })).Values.FirstOrDefault() ?? string.Empty,
                ApartmentCode = ticket.ApartmentCode,
                Status = ticket.Status,
                CreatedAtUtc = ticket.CreatedAtUtc,
                UpdatedAtUtc = ticket.UpdatedAtUtc,
                LastMessagePreview = message.Content,
                LastMessageAtUtc = message.CreatedAtUtc
            };

            if (_hub != null)
            {
                await _hub.Clients.Group(StaffHubGroup).SendAsync("TicketCreated", summary);
                await _hub.Clients.Group(TicketGroup(ticket.Id)).SendAsync("TicketCreated", summary);
            }

            return await GetTicketDetail(ticket.Id);
		}
		catch (Exception ex)
		{
            _logger.LogError(ex, "CreateTicket failed");
            return StatusCode(500, new { error = "Không thể tạo yêu cầu hỗ trợ", message = ex.Message });
		}
	}

    [HttpGet("tickets/{ticketId:guid}/messages")]
    public async Task<ActionResult<IEnumerable<SupportTicketMessageDto>>> GetMessages(Guid ticketId)
	{
		try
		{
			var me = GetUserId();
            var isManager = IsManagerLike();

            var ticket = await _db.SupportTickets
                .Include(t => t.Messages)
                .FirstOrDefaultAsync(t => t.Id == ticketId);
            if (ticket == null) return NotFound();
            if (!isManager && ticket.CreatedById != me) return Forbid();

            var userIds = ticket.Messages.Select(m => m.SenderId).Append(ticket.CreatedById);
            if (!string.IsNullOrWhiteSpace(ticket.AssignedToId))
            {
                userIds = userIds.Append(ticket.AssignedToId);
            }
            var userNames = await GetUserNamesAsync(userIds);

            var messages = ticket.Messages
                .OrderBy(m => m.CreatedAtUtc)
                .Select(m => new SupportTicketMessageDto
                {
                    Id = m.Id,
                    TicketId = m.TicketId,
                    SenderId = m.SenderId,
                    SenderName = userNames.TryGetValue(m.SenderId, out var name) ? name : string.Empty,
                    Content = m.Content,
                    AttachmentUrl = m.AttachmentUrl,
                    CreatedAtUtc = m.CreatedAtUtc,
                    IsFromStaff = m.IsFromStaff
                })
                .ToList();

            return Ok(messages);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetMessages failed for {TicketId}", ticketId);
            return StatusCode(500, new { error = "Không thể tải tin nhắn", message = ex.Message });
        }
    }

    [HttpPost("tickets/{ticketId:guid}/messages")]
    public async Task<ActionResult<SupportTicketMessageDto>> PostMessage(Guid ticketId, [FromBody] SendMessageRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Content))
        {
            return BadRequest("Tin nhắn không được để trống.");
        }

        try
        {
            var userId = GetUserId();
            var isManager = IsManagerLike();

            var ticket = await _db.SupportTickets
                .FirstOrDefaultAsync(t => t.Id == ticketId);
            if (ticket == null) return NotFound();
            if (!isManager && ticket.CreatedById != userId) return Forbid();

            var message = new SupportTicketMessage
            {
                TicketId = ticketId,
                SenderId = userId,
                Content = request.Content.Trim(),
                AttachmentUrl = request.AttachmentUrl,
                IsFromStaff = isManager
            };

            ticket.UpdatedAtUtc = DateTime.UtcNow;
            if (ticket.Status == SupportTicketStatus.New && isManager)
            {
                ticket.Status = SupportTicketStatus.InProgress;
            }

            _db.SupportTicketMessages.Add(message);
			await _db.SaveChangesAsync();

            var userNames = await GetUserNamesAsync(new[] { userId });

            var dto = new SupportTicketMessageDto
            {
                Id = message.Id,
                TicketId = message.TicketId,
                SenderId = message.SenderId,
                SenderName = userNames.TryGetValue(message.SenderId, out var name) ? name : string.Empty,
                Content = message.Content,
                AttachmentUrl = message.AttachmentUrl,
                CreatedAtUtc = message.CreatedAtUtc,
                IsFromStaff = message.IsFromStaff
            };

            if (_hub != null)
            {
                await _hub.Clients.Group(TicketGroup(ticketId)).SendAsync("TicketMessage", dto);
                if (isManager)
                {
                    await _hub.Clients.Group(StaffHubGroup).SendAsync("TicketMessage", dto);
                }
            }

            return Ok(dto);
		}
		catch (Exception ex)
		{
            _logger.LogError(ex, "PostMessage failed for {TicketId}", ticketId);
            return StatusCode(500, new { error = "Không thể gửi tin nhắn", message = ex.Message });
        }
    }

    [HttpPut("tickets/{ticketId:guid}/status")]
    [Authorize(Roles = "Manager,Security")]
    public async Task<IActionResult> UpdateStatus(Guid ticketId, [FromBody] UpdateTicketStatusRequest request)
    {
        try
        {
            var ticket = await _db.SupportTickets.FirstOrDefaultAsync(t => t.Id == ticketId);
            if (ticket == null) return NotFound();

            if (!Enum.IsDefined(typeof(SupportTicketStatus), request.Status))
            {
                return BadRequest("Trạng thái không hợp lệ.");
            }

            ticket.Status = request.Status;
            ticket.UpdatedAtUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            if (_hub != null)
            {
                await _hub.Clients.Group(TicketGroup(ticketId)).SendAsync("TicketStatusChanged", new
                {
                    ticketId,
                    status = ticket.Status.ToString()
                });

                await _hub.Clients.Group(StaffHubGroup).SendAsync("TicketStatusChanged", new
                {
                    ticketId,
                    status = ticket.Status.ToString()
                });
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateStatus failed for {TicketId}", ticketId);
            return StatusCode(500, new { error = "Không thể cập nhật trạng thái", message = ex.Message });
        }
    }

    [HttpPut("tickets/{ticketId:guid}/assign")]
    [Authorize(Roles = "Manager,Security")]
    public async Task<IActionResult> AssignTicket(Guid ticketId, [FromBody] AssignTicketRequest request)
    {
        try
        {
            var ticket = await _db.SupportTickets.FirstOrDefaultAsync(t => t.Id == ticketId);
            if (ticket == null) return NotFound();

            if (string.IsNullOrWhiteSpace(request.AssignedToId))
            {
                ticket.AssignedToId = null;
            }
            else
            {
                var exists = await _db.Users.AnyAsync(u => u.Id == request.AssignedToId);
                if (!exists)
                {
                    return BadRequest("Nhân sự gán không tồn tại.");
                }
                ticket.AssignedToId = request.AssignedToId;
            }

            ticket.UpdatedAtUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            if (_hub != null)
            {
                await _hub.Clients.Group(TicketGroup(ticketId)).SendAsync("TicketAssigned", new
                {
                    ticketId,
                    assignedToId = ticket.AssignedToId
                });

                await _hub.Clients.Group(StaffHubGroup).SendAsync("TicketAssigned", new
                {
                    ticketId,
                    assignedToId = ticket.AssignedToId
                });
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AssignTicket failed for {TicketId}", ticketId);
            return StatusCode(500, new { error = "Không thể gán người xử lý", message = ex.Message });
        }
    }
    private static string TicketGroup(Guid ticketId) => $"ticket-{ticketId}";
}

public class SupportTicketFilter : QueryParameters
{
    public string? Status { get; set; }
    public string? ApartmentCode { get; set; }
    public string? AssignedToId { get; set; }
    public string? CreatedById { get; set; }
}

public class CreateTicketRequest
{
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? Category { get; set; }
    public string? AttachmentUrl { get; set; }
}

public class SendMessageRequest
{
    public string Content { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }
}

public class UpdateTicketStatusRequest
{
    public SupportTicketStatus Status { get; set; }
}

public class AssignTicketRequest
{
    public string? AssignedToId { get; set; }
}
