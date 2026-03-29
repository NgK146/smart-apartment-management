using System.Security.Claims;
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
[Route("api/community")]
[Authorize]
public class CommunityChatController : ControllerBase
{
    private static readonly string[] AllowedImageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"];
    private static readonly string[] AllowedAudioExtensions = [".mp3", ".m4a", ".aac", ".wav", ".ogg"];

    private readonly ApplicationDbContext _db;
    private readonly IHubContext<CommunityHub> _hub;
    private readonly UserManager<AppUser> _userManager;
    private readonly IWebHostEnvironment _env;

    public CommunityChatController(
        ApplicationDbContext db,
        IHubContext<CommunityHub> hub,
        UserManager<AppUser> userManager,
        IWebHostEnvironment env)
    {
        _db = db;
        _hub = hub;
        _userManager = userManager;
        _env = env;
    }

    [HttpGet("messages")]
    public async Task<IActionResult> GetMessages(
        [FromQuery] string? room,
        [FromQuery] int limit = 50,
        [FromQuery] DateTime? before = null,
        [FromQuery] DateTime? after = null)
    {
        var normalizedRoom = NormalizeRoom(room);
        limit = Math.Clamp(limit, 1, 200);

        var query = _db.CommunityMessages
            .AsNoTracking()
            .Where(m => m.Room == normalizedRoom);

        if (before.HasValue)
        {
            var threshold = DateTime.SpecifyKind(before.Value, DateTimeKind.Utc);
            query = query.Where(m => m.CreatedAtUtc < threshold);
        }

        if (after.HasValue)
        {
            var threshold = DateTime.SpecifyKind(after.Value, DateTimeKind.Utc);
            query = query.Where(m => m.CreatedAtUtc > threshold);
        }

        var items = await query
            .OrderByDescending(m => m.CreatedAtUtc)
            .Take(limit)
            .ToListAsync();

        var result = items
            .OrderBy(m => m.CreatedAtUtc)
            .Select(ToDto)
            .ToList();

        return Ok(result);
    }

    [HttpPost("messages")]
    public async Task<IActionResult> CreateMessage([FromBody] CreateCommunityMessageRequest request)
    {
        if (request == null)
        {
            return BadRequest("Yêu cầu không hợp lệ.");
        }

        var normalizedRoom = NormalizeRoom(request.Room);
        if (string.IsNullOrWhiteSpace(request.Content) && string.IsNullOrWhiteSpace(request.FileBase64))
        {
            return BadRequest("Tin nhắn rỗng.");
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null)
        {
            return Unauthorized();
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return Unauthorized();
        }

        string? attachmentType = null;
        string? attachmentUrl = null;
        double? durationSeconds = null;

        if (!string.IsNullOrWhiteSpace(request.FileBase64))
        {
            if (string.IsNullOrWhiteSpace(request.AttachmentType))
            {
                return BadRequest("Thiếu loại tệp đính kèm.");
            }

            var ext = GetExtension(request);
            if (ext == null)
            {
                return BadRequest("Định dạng tệp không được hỗ trợ.");
            }

            attachmentType = request.AttachmentType!.ToLowerInvariant();
            var relativePath = await SaveFileAsync(request.FileBase64!, ext);
            attachmentUrl = relativePath;
            durationSeconds = request.DurationSeconds;
        }

        var message = new CommunityMessage
        {
            Room = normalizedRoom,
            SenderId = userId,
            SenderName = user.FullName ?? user.UserName ?? "Ẩn danh",
            Content = request.Content?.Trim() ?? string.Empty,
            AttachmentType = attachmentType,
            AttachmentUrl = attachmentUrl,
            AttachmentDurationSeconds = durationSeconds
        };

        _db.CommunityMessages.Add(message);
        await _db.SaveChangesAsync();

        var dto = ToDto(message);
        await _hub.Clients.Group(normalizedRoom).SendAsync("message", dto);

        return Ok(dto);
    }

    private string NormalizeRoom(string? room) =>
        string.IsNullOrWhiteSpace(room) ? "general" : room.Trim().ToLowerInvariant();

    private static CommunityMessageDto ToDto(CommunityMessage message) => new()
    {
        Id = message.Id,
        Room = message.Room,
        SenderId = message.SenderId,
        SenderName = message.SenderName,
        Content = message.Content,
        AttachmentType = message.AttachmentType,
        AttachmentUrl = message.AttachmentUrl,
        AttachmentDurationSeconds = message.AttachmentDurationSeconds,
        CreatedAtUtc = message.CreatedAtUtc
    };

    private static string? GetExtension(CreateCommunityMessageRequest request)
    {
        var attachmentType = request.AttachmentType?.ToLowerInvariant();
        var fileName = request.FileName?.Trim();

        string? ext = null;
        if (!string.IsNullOrEmpty(fileName))
        {
            ext = Path.GetExtension(fileName).ToLowerInvariant();
        }

        if (string.IsNullOrEmpty(ext))
        {
            ext = attachmentType switch
            {
                "image" => ".jpg",
                "audio" => ".m4a",
                _ => null
            };
        }

        if (string.IsNullOrEmpty(ext))
        {
            return null;
        }

        var allowed = attachmentType == "audio" ? AllowedAudioExtensions : AllowedImageExtensions;
        return allowed.Contains(ext) ? ext : null;
    }

    private async Task<string> SaveFileAsync(string base64, string extension)
    {
        var data = base64 switch
        {
            var s when s.Contains(",") => s.Split(',', 2)[1],
            _ => base64
        };
        var bytes = Convert.FromBase64String(data);

        var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        var folder = Path.Combine(webRoot, "uploads", "community", DateTime.UtcNow.ToString("yyyy_MM"));
        Directory.CreateDirectory(folder);

        var filename = $"{Guid.NewGuid():N}{extension}";
        var fullPath = Path.Combine(folder, filename);
        await System.IO.File.WriteAllBytesAsync(fullPath, bytes);

        var relative = Path.Combine("uploads", "community", DateTime.UtcNow.ToString("yyyy_MM"), filename)
            .Replace("\\", "/");
        return "/" + relative;
    }

    public class CreateCommunityMessageRequest
    {
        public string? Room { get; set; }
        public string? Content { get; set; }
        public string? AttachmentType { get; set; }
        public string? FileBase64 { get; set; }
        public string? FileName { get; set; }
        public double? DurationSeconds { get; set; }
    }

    public class CommunityMessageDto
    {
        public Guid Id { get; set; }
        public string Room { get; set; } = "general";
        public string SenderId { get; set; } = string.Empty;
        public string SenderName { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public string? AttachmentType { get; set; }
        public string? AttachmentUrl { get; set; }
        public double? AttachmentDurationSeconds { get; set; }
        public DateTime CreatedAtUtc { get; set; }
    }
}

