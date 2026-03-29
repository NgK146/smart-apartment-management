using ICitizen.Data;
using ICitizen.Domain; // Complaint, ComplaintStatus, ComplaintCategory, AppUser, SupportTicket
using ICitizen.Models;
using ICitizen.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Reflection;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public sealed class ComplaintsController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly IHubContext<SupportHub>? _supportHub;
        private readonly IHubContext<NotificationHub>? _notificationHub;

        private const string StaffHubGroup = "support-staff";

        private async Task NotifyManagersAsync(string title, string message, string refType, Guid refId)
        {
            try
            {
                // lấy tất cả userId có role Manager
                var managerRoleId = await _db.Roles
                    .Where(r => r.Name == "Manager")
                    .Select(r => r.Id)
                    .FirstOrDefaultAsync();
                if (managerRoleId == null) return;

                var managerIds = await _db.UserRoles
                    .Where(ur => ur.RoleId == managerRoleId)
                    .Select(ur => ur.UserId)
                    .ToListAsync();

                foreach (var uid in managerIds)
                {
                    var n = new UserNotification
                    {
                        UserId = uid,
                        Title = title,
                        Message = message,
                        Type = "Complaint",
                        RefType = refType,
                        RefId = refId,
                        CreatedAtUtc = DateTime.UtcNow
                    };
                    _db.UserNotifications.Add(n);
                }
                await _db.SaveChangesAsync();

                if (_notificationHub != null)
                {
                    foreach (var uid in managerIds)
                    {
                        var unread = await _db.UserNotifications.CountAsync(x => x.UserId == uid && x.ReadAtUtc == null && !x.IsDeleted);
                        await _notificationHub.Clients.Group("managers").SendAsync("userNotification", new
                        {
                            title,
                            message,
                            type = "Complaint",
                            refType,
                            refId,
                            unreadCount = unread
                        });
                    }
                }
            }
            catch
            {
                // không làm hỏng luồng chính
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
                    Type = "Complaint",
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
                // bỏ qua lỗi nhỏ
            }
        }

        public ComplaintsController(
            ApplicationDbContext db,
            UserManager<AppUser> userManager,
            IHubContext<SupportHub>? supportHub = null,
            IHubContext<NotificationHub>? notificationHub = null)
        {
            _db = db;
            _userManager = userManager;
            _supportHub = supportHub;
            _notificationHub = notificationHub;
        }

        // ---------- Helpers ----------
        private static bool TryParseEnum<TEnum>(string? value, out TEnum result) where TEnum : struct
        {
            if (!string.IsNullOrWhiteSpace(value) && Enum.TryParse(value, true, out result))
                return true;
            result = default;
            return false;
        }

        private static string? GetStringProp(object obj, params string[] names)
        {
            foreach (var n in names)
            {
                var pi = obj.GetType().GetProperty(n, BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);
                if (pi == null) continue;
                var v = pi.GetValue(obj);
                if (v == null) continue;
                if (v is Guid g) return g.ToString();
                return v.ToString();
            }
            return null;
        }

        private static void TrySet(object obj, string prop, object? value)
        {
            var pi = obj.GetType().GetProperty(prop, BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);
            if (pi != null && pi.CanWrite) pi.SetValue(obj, value);
        }

        // GET /api/Complaints - Lấy danh sách phản ánh (User chỉ thấy của mình, Manager thấy tất cả)
        [HttpGet]
        public async Task<IActionResult> List(
            [FromQuery] string? status,
            [FromQuery] string? category,
            [FromQuery] bool? assignedToMe,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            try
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

                var isManager = User.IsInRole("Manager");
                var q = _db.Complaints.Where(c => !c.IsDeleted).AsQueryable();

                // User chỉ thấy phản ánh của mình, Manager thấy tất cả
                if (!isManager)
                    q = q.Where(c => c.CreatedByUserId == me.Id);

            if (TryParseEnum<ComplaintStatus>(status, out var st))
                q = q.Where(c => c.Status.Equals(st));

            if (TryParseEnum<ComplaintCategory>(category, out var cat))
                q = q.Where(c => c.Category.Equals(cat));

            var total = await q.CountAsync();

            var data = await q
                .OrderByDescending(c => c.CreatedAtUtc)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

                if (assignedToMe == true && isManager)
            {
                    var myId = me.Id;
                data = data.Where(c =>
                {
                    var assignee = GetStringProp(c, "AssignedToUserId", "AssignedToId", "AssigneeId");
                    return assignee != null && string.Equals(assignee, myId, StringComparison.OrdinalIgnoreCase);
                }).ToList();
            }

            var items = data.Select(c => new
            {
                    id = c.Id,
                    title = c.Title ?? string.Empty,
                    tieuDe = c.Title ?? string.Empty,
                    content = c.Content ?? string.Empty,
                    noiDung = c.Content ?? string.Empty,
                    category = c.Category.ToString(),
                    status = c.Status.ToString(),
                    createdAtUtc = c.CreatedAtUtc,
                    ngayGui = c.CreatedAtUtc,
                    createdBy = GetStringProp(c, "CreatedByName", "CreatedByUsername"),
                    phanHoiAdmin = c.PhanHoiAdmin ?? string.Empty,
                    emailNguoiGui = c.EmailNguoiGui,
                tenNguoiGui = c.TenNguoiGui,
                mediaUrls = c.MediaUrls
            }).ToList();

            return Ok(new { page, pageSize, total, items });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi tải danh sách phản ánh", message = ex.Message });
            }
        }

        // POST /api/Complaints - Gửi phản ánh (User)
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateComplaintRequest req)
        {
            try
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var entity = new Complaint
            {
                Title = req.Title,
                Content = req.Content,
                    CreatedAtUtc = DateTime.UtcNow,
                    CreatedByUserId = me.Id,
                    EmailNguoiGui = req.EmailNguoiGui ?? me.Email,
                    TenNguoiGui = req.TenNguoiGui ?? me.FullName ?? me.UserName,
                Status = ComplaintStatus.Pending, // Mặc định "Chưa xử lý"
                MediaUrls = string.IsNullOrWhiteSpace(req.MediaUrls) ? null : req.MediaUrls
            };

            if (TryParseEnum<ComplaintCategory>(req.Category, out var cat))
                entity.Category = cat;

            _db.Complaints.Add(entity);
            await _db.SaveChangesAsync();

                // Thông báo cho BQL khi cư dân gửi phản ánh
                _ = NotifyManagersAsync(
                    $"Phản ánh mới: {entity.Title ?? "Phản ánh"}",
                    $"{me.FullName ?? me.UserName ?? "Cư dân"} vừa gửi phản ánh. Trạng thái: {entity.Status}",
                    "ComplaintCreated",
                    entity.Id);

                // Thông báo lại cho cư dân (xác nhận đã gửi)
                _ = NotifyUserAsync(me.Id,
                    $"Đã gửi phản ánh: {entity.Title ?? "Phản ánh"}",
                    "Phản ánh của bạn đã được gửi, BQL sẽ xử lý sớm.",
                    "ComplaintCreated",
                    entity.Id);

                return Ok(new
            {
                    message = "Gửi phản ánh thành công",
                    phanAnhId = entity.Id,
                    id = entity.Id,
                    title = entity.Title,
                    tieuDe = entity.Title,
                    content = entity.Content,
                    noiDung = entity.Content,
                    category = entity.Category.ToString(),
                    loaiPhanAnh = entity.Category.ToString(),
                    status = entity.Status.ToString(),
                    trangThai = entity.Status.ToString(),
                    createdBy = me.UserName,
                    emailNguoiGui = entity.EmailNguoiGui,
                    tenNguoiGui = entity.TenNguoiGui,
                    createdAtUtc = entity.CreatedAtUtc,
                    ngayGui = entity.CreatedAtUtc,
                    mediaUrls = entity.MediaUrls
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi gửi phản ánh", message = ex.Message });
            }
        }

        // GET /api/Complaints/me - Lấy danh sách phản ánh của user hiện tại
        [HttpGet("me")]
        public async Task<IActionResult> GetMyComplaints([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
        {
            try
            {
                var me = await _userManager.GetUserAsync(User);
                if (me == null) return Unauthorized();

                if (page < 1) page = 1;
                if (pageSize < 1 || pageSize > 200) pageSize = 20;

                var q = _db.Complaints.Where(c => c.CreatedByUserId == me.Id && !c.IsDeleted);

                var total = await q.CountAsync();
                
                // Lấy dữ liệu trước, sau đó map để tránh lỗi trong Select
                var data = await q
                    .OrderByDescending(c => c.CreatedAtUtc)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                var items = data.Select(c => new
                {
                    id = c.Id,
                    tieuDe = c.Title ?? string.Empty,
                    title = c.Title ?? string.Empty,
                    noiDung = c.Content ?? string.Empty,
                    content = c.Content ?? string.Empty,
                    loaiPhanAnh = c.Category.ToString(),
                    category = c.Category.ToString(),
                    trangThai = c.Status.ToString(),
                    status = c.Status.ToString(),
                    phanHoiAdmin = c.PhanHoiAdmin ?? string.Empty,
                    ngayGui = c.CreatedAtUtc,
                    createdAtUtc = c.CreatedAtUtc,
                    ngayCapNhat = c.UpdatedAtUtc.HasValue ? c.UpdatedAtUtc.Value : c.CreatedAtUtc,
                    emailNguoiGui = c.EmailNguoiGui,
                    tenNguoiGui = c.TenNguoiGui,
                    mediaUrls = c.MediaUrls
                }).ToList();

                return Ok(new { page, pageSize, total, items });
            }
            catch (Exception ex)
            {
                // Log chi tiết lỗi để debug
                System.Diagnostics.Debug.WriteLine($"Error in GetMyComplaints: {ex.Message}");
                System.Diagnostics.Debug.WriteLine($"Stack trace: {ex.StackTrace}");
                if (ex.InnerException != null)
                {
                    System.Diagnostics.Debug.WriteLine($"Inner exception: {ex.InnerException.Message}");
                }
                return StatusCode(500, new { error = "Lỗi khi tải danh sách phản ánh", message = ex.Message });
            }
        }

        // GET /api/Complaints/{id} - Xem chi tiết phản ánh
        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetDetails(Guid id)
        {
            try
            {
                var me = await _userManager.GetUserAsync(User);
                if (me == null) return Unauthorized();

                var isManager = User.IsInRole("Manager");
                var complaint = await _db.Complaints
                    .Include(c => c.Comments)
                    .FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);

                if (complaint == null) return NotFound("Không tìm thấy phản ánh.");

                // User chỉ xem được phản ánh của mình, Manager xem được tất cả
                if (!isManager && complaint.CreatedByUserId != me.Id)
                    return Forbid("Bạn không có quyền xem phản ánh này.");

                // Load all comment users
                var commentUserIds = complaint.Comments.Select(c => c.UserId).Distinct().ToList();
                var commentUsers = await _userManager.Users
                    .Where(u => commentUserIds.Contains(u.Id))
                    .ToListAsync();
                var commentUserDict = commentUsers.ToDictionary(u => u.Id, u => u);
                var commentUserRoles = new Dictionary<string, bool>();
                foreach (var userId in commentUserIds)
                {
                    var user = commentUserDict.TryGetValue(userId, out var name) ? name : null;
                    if (user != null)
                    {
                        var roles = await _userManager.GetRolesAsync(user);
                        commentUserRoles[userId] = roles.Contains("Manager") || roles.Contains("Security");
                    }
                }

                var result = new
                {
                    id = complaint.Id,
                    title = complaint.Title,
                    tieuDe = complaint.Title,
                    content = complaint.Content,
                    noiDung = complaint.Content,
                    category = complaint.Category.ToString(),
                    loaiPhanAnh = complaint.Category.ToString(),
                    status = complaint.Status.ToString(),
                    trangThai = complaint.Status.ToString(),
                    emailNguoiGui = complaint.EmailNguoiGui,
                    tenNguoiGui = complaint.TenNguoiGui,
                    phanHoiAdmin = complaint.PhanHoiAdmin,
                    createdAtUtc = complaint.CreatedAtUtc,
                    ngayGui = complaint.CreatedAtUtc,
                    ngayCapNhat = complaint.UpdatedAtUtc ?? complaint.CreatedAtUtc,
                    createdBy = me.UserName,
                    mediaUrls = complaint.MediaUrls,
                    comments = complaint.Comments.OrderBy(c => c.CreatedAtUtc).Select(c =>
                    {
                        var commentUser = commentUserDict.TryGetValue(c.UserId, out var cu) ? cu : null;
                        var isCommentAdmin = commentUserRoles.TryGetValue(c.UserId, out var role) ? role : false;
                        return new
                        {
                            id = c.Id,
                            message = c.Message,
                            userId = c.UserId,
                            userName = commentUser?.UserName ?? commentUser?.FullName ?? "Unknown",
                            isAdmin = isCommentAdmin,
                            ngayGui = c.CreatedAtUtc,
                            createdAtUtc = c.CreatedAtUtc
                        };
                    }).ToList()
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi tải chi tiết phản ánh", message = ex.Message });
            }
        }

        // POST /api/Complaints/{id}/assign-to-me
        [Authorize(Roles = "Security,Vendor,Manager")]
        [HttpPost("{id:guid}/assign-to-me")]
        public async Task<IActionResult> AssignToMe(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var c = await _db.Complaints.FirstOrDefaultAsync(x => x.Id == id);
            if (c == null) return NotFound();

            TrySet(c, "AssignedToUserId", me.Id);
            TrySet(c, "AssignedToId", me.Id);
            TrySet(c, "AssigneeId", me.Id);

            await _db.SaveChangesAsync();
            return Ok("Đã nhận việc.");
        }

        // POST /api/Complaints/{id}/status   body: { "status": "InProgress" }
        [Authorize(Roles = "Security,Vendor,Manager")]
        [HttpPost("{id:guid}/status")]
        public async Task<IActionResult> SetStatus(Guid id, [FromBody] SetComplaintStatusRequest req)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            if (!Enum.TryParse<ComplaintStatus>(req.Status, true, out var newStatus))
                return BadRequest("Trạng thái không hợp lệ.");

            var c = await _db.Complaints.FirstOrDefaultAsync(x => x.Id == id);
            if (c == null) return NotFound();

            c.Status = newStatus;
            await _db.SaveChangesAsync();
            return Ok("Đã cập nhật trạng thái.");
        }

        // POST /api/Complaints/{id}/comments - Gửi comment (User và Admin đều được)
        [HttpPost("{id:guid}/comments")]
        public async Task<IActionResult> AddComment(Guid id, [FromBody] AddCommentRequest req)
        {
            try
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();
                if (string.IsNullOrWhiteSpace(req.Message)) return BadRequest("Nội dung rỗng.");

                var c = await _db.Complaints.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted);
                if (c == null) return NotFound("Không tìm thấy phản ánh.");

                var isManager = User.IsInRole("Manager");
                // User chỉ comment được phản ánh của mình
                if (!isManager && c.CreatedByUserId != me.Id)
                    return Forbid("Bạn không có quyền bình luận phản ánh này.");

            var cm = new ComplaintComment
            {
                    ComplaintId = id,
                    UserId = me.Id,
                    Message = req.Message,
                CreatedAtUtc = DateTime.UtcNow
            };

                _db.ComplaintComments.Add(cm);
                
                // Nếu admin comment, tự động chuyển trạng thái sang InProgress nếu đang Pending
                if (isManager && c.Status == ComplaintStatus.Pending)
                {
                    c.Status = ComplaintStatus.InProgress;
                }
                
                await _db.SaveChangesAsync();

                // Trả về comment vừa tạo
                var user = await _userManager.FindByIdAsync(me.Id);
                return Ok(new
                {
                    id = cm.Id,
                    message = cm.Message,
                    userId = cm.UserId,
                    userName = user?.UserName ?? user?.FullName ?? "Unknown",
                    isAdmin = isManager,
                    createdAtUtc = cm.CreatedAtUtc,
                    ngayGui = cm.CreatedAtUtc
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi gửi bình luận", message = ex.Message });
            }
        }
    }

    // ====== ADMIN ENDPOINTS ======
    [ApiController]
    [Route("api/admin/Complaints")]
    [Authorize(Roles = "Manager")]
    public sealed class AdminComplaintsController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly IHubContext<SupportHub>? _supportHub;

        private const string StaffHubGroup = "support-staff";

        private readonly IHubContext<NotificationHub>? _notificationHub;

        public AdminComplaintsController(
            ApplicationDbContext db,
            UserManager<AppUser> um,
            IHubContext<SupportHub>? supportHub = null,
            IHubContext<NotificationHub>? notificationHub = null)
        {
            _db = db;
            _userManager = um;
            _supportHub = supportHub;
            _notificationHub = notificationHub;
        }

        // GET /api/admin/Complaints - Danh sách phản ánh (Admin)
        [HttpGet]
        public async Task<IActionResult> List(
            [FromQuery] string? trangThai,
            [FromQuery] string? loaiPhanAnh,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                if (page < 1) page = 1;
                if (pageSize < 1 || pageSize > 200) pageSize = 50;

                var q = _db.Complaints.Where(c => !c.IsDeleted).AsQueryable();

                // Lọc theo trạng thái
                if (!string.IsNullOrWhiteSpace(trangThai))
                {
                    if (Enum.TryParse<ComplaintStatus>(trangThai, true, out var status))
                        q = q.Where(c => c.Status == status);
                }

                // Lọc theo loại phản ánh
                if (!string.IsNullOrWhiteSpace(loaiPhanAnh))
                {
                    if (Enum.TryParse<ComplaintCategory>(loaiPhanAnh, true, out var category))
                        q = q.Where(c => c.Category == category);
                }

                // Tìm kiếm theo từ khóa
                if (!string.IsNullOrWhiteSpace(search))
                {
                    search = search.ToLower().Trim();
                    q = q.Where(c => 
                        c.Title.ToLower().Contains(search) || 
                        c.Content.ToLower().Contains(search) ||
                        (c.TenNguoiGui != null && c.TenNguoiGui.ToLower().Contains(search)) ||
                        (c.EmailNguoiGui != null && c.EmailNguoiGui.ToLower().Contains(search)));
                }

                var total = await q.CountAsync();
                // Lấy dữ liệu trước, sau đó map để đảm bảo format đúng
                var data = await q
                    .OrderByDescending(c => c.CreatedAtUtc)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                var items = data.Select(c => new
                {
                    id = c.Id,
                    title = c.Title ?? string.Empty,
                    tieuDe = c.Title ?? string.Empty,
                    content = c.Content ?? string.Empty,
                    noiDung = c.Content ?? string.Empty,
                    category = c.Category.ToString(),
                    loaiPhanAnh = c.Category.ToString(),
                    status = c.Status.ToString(),
                    trangThai = c.Status.ToString(),
                    tenNguoiGui = c.TenNguoiGui,
                    emailNguoiGui = c.EmailNguoiGui,
                    phanHoiAdmin = c.PhanHoiAdmin ?? string.Empty,
                    createdAtUtc = c.CreatedAtUtc,
                    ngayGui = c.CreatedAtUtc,
                    ngayCapNhat = c.UpdatedAtUtc.HasValue ? c.UpdatedAtUtc.Value : c.CreatedAtUtc,
                    mediaUrls = c.MediaUrls
                }).ToList();

                return Ok(new { page, pageSize, total, items });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi tải danh sách phản ánh", message = ex.Message });
            }
        }

        // GET /api/admin/Complaints/{id} - Chi tiết phản ánh (Admin)
        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetDetails(Guid id)
        {
            try
            {
                var complaint = await _db.Complaints
                    .Include(c => c.Comments)
                    .FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);

                if (complaint == null) return NotFound("Không tìm thấy phản ánh.");

                // Lấy thông tin người gửi
                var user = await _userManager.FindByIdAsync(complaint.CreatedByUserId);
                
                var result = new
                {
                    id = complaint.Id,
                    tieuDe = complaint.Title,
                    noiDung = complaint.Content,
                    loaiPhanAnh = complaint.Category.ToString(),
                    trangThai = complaint.Status.ToString(),
                    tenNguoiGui = complaint.TenNguoiGui ?? user?.FullName ?? user?.UserName,
                    emailNguoiGui = complaint.EmailNguoiGui ?? user?.Email,
                    phanHoiAdmin = complaint.PhanHoiAdmin,
                    ngayGui = complaint.CreatedAtUtc,
                    ngayCapNhat = complaint.UpdatedAtUtc ?? complaint.CreatedAtUtc,
                    mediaUrls = complaint.MediaUrls,
                    comments = complaint.Comments.OrderBy(c => c.CreatedAtUtc).Select(c =>
                    {
                        // Note: For admin endpoint, we'd need to load users similarly
                        // For now, return basic info
                        return new
                        {
                            id = c.Id,
                            message = c.Message,
                            userId = c.UserId,
                            userName = (string?)null,
                            isAdmin = (bool?)null,
                            ngayGui = c.CreatedAtUtc,
                            createdAtUtc = c.CreatedAtUtc
                        };
                    }).ToList()
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi tải chi tiết phản ánh", message = ex.Message });
            }
        }

        // PUT /api/admin/Complaints/{id} - Cập nhật phản ánh (Admin)
        [HttpPut("{id:guid}")]
        public async Task<IActionResult> Update(Guid id, [FromBody] UpdateComplaintRequest req)
        {
            try
            {
                var complaint = await _db.Complaints.FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);
                if (complaint == null) return NotFound("Không tìm thấy phản ánh.");

                // Cập nhật trạng thái nếu có
                if (!string.IsNullOrWhiteSpace(req.TrangThai))
                {
                    if (Enum.TryParse<ComplaintStatus>(req.TrangThai, true, out var newStatus))
                    {
                        complaint.Status = newStatus;
                        if (newStatus == ComplaintStatus.Resolved)
                            complaint.ResolvedAtUtc = DateTime.UtcNow;
                    }
                }

                // Cập nhật phản hồi admin
                if (req.PhanHoiAdmin != null)
                {
                    complaint.PhanHoiAdmin = req.PhanHoiAdmin;
                    complaint.UpdatedAtUtc = DateTime.UtcNow;
                    // Nếu có phản hồi, tự động chuyển trạng thái thành "Đã phản hồi" (nếu chưa phải Resolved)
                    if (complaint.Status != ComplaintStatus.Resolved)
                        complaint.Status = ComplaintStatus.InProgress; // Hoặc tạo enum mới "Đã phản hồi"
                }

                await _db.SaveChangesAsync();

                // Sau khi cập nhật, tạo 1 SupportTicket để cư dân nhận được thông báo real-time qua module Hỗ trợ
                if (_supportHub != null && !string.IsNullOrWhiteSpace(complaint.CreatedByUserId))
                {
                    await CreateSupportTicketNotificationForComplaintAsync(complaint);
                }

                return Ok(new { message = "Đã cập nhật phản ánh thành công." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi cập nhật phản ánh", message = ex.Message });
            }
        }

        // DELETE /api/admin/Complaints/{id} - Xóa phản ánh (Admin)
        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            try
            {
                var complaint = await _db.Complaints.FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);
                if (complaint == null) return NotFound("Không tìm thấy phản ánh.");

                // Soft delete
                complaint.IsDeleted = true;
                complaint.UpdatedAtUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync();

                return NoContent();
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi xóa phản ánh", message = ex.Message });
            }
        }

        // GET /api/admin/Complaints/stats - Thống kê phản ánh
        [HttpGet("stats")]
        public async Task<IActionResult> GetStats()
        {
            try
            {
                var total = await _db.Complaints.CountAsync(c => !c.IsDeleted);
                var chuaXuLy = await _db.Complaints.CountAsync(c => !c.IsDeleted && c.Status == ComplaintStatus.Pending);
                // Đã phản hồi = có PhanHoiAdmin hoặc có comment từ admin/manager
                var complaintsWithResponse = await _db.Complaints
                    .Where(c => !c.IsDeleted && 
                        ((c.PhanHoiAdmin != null && c.PhanHoiAdmin != string.Empty) ||
                         _db.ComplaintComments.Any(cc => cc.ComplaintId == c.Id)))
                    .Select(c => c.Id)
                    .ToListAsync();
                var daPhanHoi = complaintsWithResponse.Count;
                var daDong = await _db.Complaints.CountAsync(c => !c.IsDeleted && c.Status == ComplaintStatus.Resolved);

                return Ok(new
                {
                    tongSo = total,
                    chuaXuLy,
                    daPhanHoi,
                    daDong
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Lỗi khi tải thống kê", message = ex.Message });
            }
        }

        private static SupportTicketStatus MapComplaintStatusToTicketStatus(ComplaintStatus status)
        {
            return status switch
            {
                ComplaintStatus.Pending => SupportTicketStatus.New,
                ComplaintStatus.InProgress => SupportTicketStatus.InProgress,
                ComplaintStatus.Resolved => SupportTicketStatus.Resolved,
                ComplaintStatus.Rejected => SupportTicketStatus.Closed,
                _ => SupportTicketStatus.New
            };
        }

        private static string BuildComplaintNotificationMessage(Complaint complaint)
        {
            var statusText = complaint.Status switch
            {
                ComplaintStatus.Pending => "Chưa xử lý",
                ComplaintStatus.InProgress => "Đang xử lý",
                ComplaintStatus.Resolved => "Đã xử lý",
                ComplaintStatus.Rejected => "Đã từ chối",
                _ => complaint.Status.ToString()
            };

            var baseMsg = $"Phản ánh \"{complaint.Title}\" của bạn đã được cập nhật trạng thái: {statusText}.";

            if (!string.IsNullOrWhiteSpace(complaint.PhanHoiAdmin))
            {
                baseMsg += $" Phản hồi từ Ban quản lý: {complaint.PhanHoiAdmin}";
            }

            return baseMsg;
        }

        /// <summary>
        /// Tạo một SupportTicket + tin nhắn hệ thống để cư dân nhận thông báo qua module Hỗ trợ / Ticket.
        /// </summary>
        private async Task CreateSupportTicketNotificationForComplaintAsync(Complaint complaint)
        {
            try
            {
                var admin = await _userManager.GetUserAsync(User);
                if (admin == null || string.IsNullOrWhiteSpace(complaint.CreatedByUserId))
                    return;

                var ticket = new SupportTicket
                {
                    Title = $"Phản ánh: {complaint.Title ?? "Không tiêu đề"}",
                    CreatedById = complaint.CreatedByUserId,
                    ApartmentCode = null,
                    Category = $"Complaint/{complaint.Category}",
                    Status = MapComplaintStatusToTicketStatus(complaint.Status)
                };

                var message = new SupportTicketMessage
                {
                    Ticket = ticket,
                    SenderId = admin.Id,
                    Content = BuildComplaintNotificationMessage(complaint),
                    IsFromStaff = true
                };

                _db.SupportTickets.Add(ticket);
                _db.SupportTicketMessages.Add(message);
                await _db.SaveChangesAsync();

                // Gửi sự kiện real-time qua SignalR (SupportHub)
                if (_supportHub != null)
                {
                    // Cập nhật trạng thái ticket cho cư dân + staff
                    await _supportHub.Clients.Group($"ticket-{ticket.Id}").SendAsync("TicketStatusChanged", new
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

                    // Gửi thêm tin nhắn hệ thống vào phòng chat của ticket
                    await _supportHub.Clients.Group($"ticket-{ticket.Id}").SendAsync("TicketMessage", new
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
            }
            catch
            {
                // Không để lỗi notification làm hỏng luồng chính
            }
        }
    }
}
