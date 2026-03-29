using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class NotificationsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<AppUser> _userManager;
    
    public NotificationsController(ApplicationDbContext db, UserManager<AppUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    // Cư dân đều xem được thông báo (cúp điện/nước, bảo trì, sự kiện...) :contentReference[oaicite:14]{index=14}
    [HttpGet]
    [Authorize]
    public async Task<IActionResult> List([FromQuery] QueryParameters p, [FromQuery] bool onlyActive = false)
    {
        try
        {
            var now = DateTime.UtcNow;
            var q = _db.Notifications.AsQueryable();
            if (onlyActive) q = q.Where(n => (n.EffectiveFrom == null || n.EffectiveFrom <= now)
                                          && (n.EffectiveTo == null || n.EffectiveTo >= now));
            if (!string.IsNullOrWhiteSpace(p.Search))
                q = q.Where(n => n.Title.Contains(p.Search) || n.Content.Contains(p.Search));
            q = q.OrderByDescending(x => x.CreatedAtUtc);
            
            var total = await q.CountAsync();
            
            // Lấy danh sách notification
            var notifications = await q
                .Skip((p.Page - 1) * p.PageSize)
                .Take(p.PageSize)
                .Select(n => new
                {
                    n.Id,
                    n.Title,
                    n.Content,
                    n.Type,
                    n.CreatedAtUtc,
                    n.EffectiveFrom,
                    n.EffectiveTo,
                    n.CreatedByUserId
                })
                .ToListAsync();
            
            // Lấy danh sách notification IDs
            var notificationIds = notifications.Select(n => n.Id).ToList();
            
            // Lấy thông tin post cho các notification
            var posts = await _db.CommunityPosts
                .Where(post => notificationIds.Contains(post.NotificationId ?? Guid.Empty) && !post.IsDeleted)
                .Select(post => new
                {
                    NotificationId = post.NotificationId,
                    PostId = post.Id,
                    LikeCount = post.Likes.Count,
                    CommentCount = post.Comments.Count(c => !c.IsDeleted && !c.IsHidden) // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                })
                .ToListAsync();
            
            // Tạo dictionary để tra cứu nhanh
            var postDict = posts.ToDictionary(
                x => x.NotificationId!.Value,
                x => new { x.PostId, x.LikeCount, x.CommentCount }
            );
            
            // Kết hợp thông tin
            var items = notifications.Select(n =>
            {
                var postInfo = postDict.TryGetValue(n.Id, out var info) ? info : null;
                return new
                {
                    n.Id,
                    n.Title,
                    n.Content,
                    n.Type,
                    n.CreatedAtUtc,
                    n.EffectiveFrom,
                    n.EffectiveTo,
                    n.CreatedByUserId,
                    PostId = postInfo?.PostId,
                    LikeCount = postInfo?.LikeCount ?? 0,
                    CommentCount = postInfo?.CommentCount ?? 0
                };
            }).ToList();
            
            var result = new
            {
                items,
                total,
                page = p.Page,
                pageSize = p.PageSize,
                totalPages = (int)Math.Ceiling((double)total / p.PageSize)
            };
            
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách thông báo", message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    [Authorize]
    public async Task<IActionResult> Get(Guid id)
    {
        var m = await _db.Notifications.FindAsync(id);
        if (m is null) return NotFound();
        
        // Tìm CommunityPost liên quan để lấy thông tin like/comment
        var relatedPost = await _db.CommunityPosts
            .Where(p => p.NotificationId == id && !p.IsDeleted)
            .Select(p => new
            {
                p.Id,
                LikeCount = p.Likes.Count,
                CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden) // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
            })
            .FirstOrDefaultAsync();
        
        var result = new
        {
            m.Id,
            m.Title,
            m.Content,
            m.Type,
            m.CreatedAtUtc,
            m.EffectiveFrom,
            m.EffectiveTo,
            m.CreatedByUserId,
            PostId = relatedPost?.Id,
            LikeCount = relatedPost?.LikeCount ?? 0,
            CommentCount = relatedPost?.CommentCount ?? 0
        };
        
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<Notification>> Create(Notification m)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        m.CreatedByUserId = userId;
        
        // Lấy thông tin user để tạo CommunityPost
        var user = await _userManager.FindByIdAsync(userId);
        var userName = user != null ? (user.FullName ?? user.UserName ?? "Ban Quản Trị") : "Ban Quản Trị";
        
        _db.Notifications.Add(m);
        await _db.SaveChangesAsync();
        
        // Tự động tạo CommunityPost với type=News khi admin tạo Notification
        try
        {
            var post = new CommunityPost
            {
                Type = PostType.News,
                Title = m.Title,
                Content = m.Content,
                CreatedById = userId,
                CreatedByName = userName,
                ApartmentCode = null, 
                NotificationId = m.Id, 
                ImageUrls = new List<string>() 
            };
            
            _db.CommunityPosts.Add(post);
            await _db.SaveChangesAsync();
            
            // Log thành công
            System.Diagnostics.Debug.WriteLine($"Đã tạo CommunityPost từ Notification: {post.Id}, Title: {post.Title}");
        }
        catch (Exception ex)
        {
            // Log lỗi chi tiết
            System.Diagnostics.Debug.WriteLine($"LỖI khi tạo CommunityPost từ Notification: {ex.Message}");
            System.Diagnostics.Debug.WriteLine($"Stack trace: {ex.StackTrace}");
            if (ex.InnerException != null)
            {
                System.Diagnostics.Debug.WriteLine($"Inner exception: {ex.InnerException.Message}");
            }
            // Ném lại exception để biết có lỗi
            throw new Exception($"Không thể tạo bài đăng trong bảng tin: {ex.Message}", ex);
        }
        
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, Notification m)
    {
        var dbm = await _db.Notifications.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Title = m.Title; dbm.Content = m.Content; dbm.Type = m.Type;
        dbm.EffectiveFrom = m.EffectiveFrom; dbm.EffectiveTo = m.EffectiveTo;
        await _db.SaveChangesAsync();
        
        // Cập nhật CommunityPost tương ứng (nếu có)
        var relatedPost = await _db.CommunityPosts
            .FirstOrDefaultAsync(p => p.NotificationId == id && !p.IsDeleted);
        if (relatedPost != null)
        {
            relatedPost.Title = m.Title;
            relatedPost.Content = m.Content;
            await _db.SaveChangesAsync();
        }
        
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.Notifications.FindAsync(id);
        if (m is null) return NotFound();
        
        // Xóa CommunityPost tương ứng (soft delete)
        var relatedPost = await _db.CommunityPosts
            .FirstOrDefaultAsync(p => p.NotificationId == id && !p.IsDeleted);
        if (relatedPost != null)
        {
            relatedPost.IsDeleted = true;
            await _db.SaveChangesAsync();
        }
        
        _db.Notifications.Remove(m);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    // POST /api/Notifications/
    [HttpPost("migrate")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> MigrateOldNotifications()
    {
        try
        {
            // Lấy tất cả Notification chưa có CommunityPost tương ứng
            var notifications = await _db.Notifications
                .Where(n => !_db.CommunityPosts.Any(p => p.NotificationId == n.Id))
                .ToListAsync();

            var count = 0;
            foreach (var notification in notifications)
            {
                try
                {
                    // Lấy thông tin user
                    var user = await _userManager.FindByIdAsync(notification.CreatedByUserId);
                    var userName = user != null ? (user.FullName ?? user.UserName ?? "Ban Quản Trị") : "Ban Quản Trị";

                    var post = new CommunityPost
                    {
                        Type = PostType.News,
                        Title = notification.Title,
                        Content = notification.Content,
                        CreatedById = notification.CreatedByUserId,
                        CreatedByName = userName,
                        ApartmentCode = null,
                        NotificationId = notification.Id,
                        ImageUrls = new List<string>(),
                        CreatedAtUtc = notification.CreatedAtUtc // Giữ nguyên thời gian tạo
                    };

                    _db.CommunityPosts.Add(post);
                    count++;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Lỗi migrate Notification {notification.Id}: {ex.Message}");
                }
            }

            await _db.SaveChangesAsync();

            return Ok(new { message = $"Đã migrate {count} thông báo sang bảng tin", count });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi migrate thông báo", message = ex.Message });
        }
    }
}
