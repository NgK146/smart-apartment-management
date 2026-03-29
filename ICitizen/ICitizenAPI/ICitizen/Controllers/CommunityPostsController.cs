using System.Security.Claims;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/community/posts")]
[Authorize]
public class CommunityPostsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<AppUser> _userManager;

    public CommunityPostsController(ApplicationDbContext db, UserManager<AppUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    // GET /api/community/posts - Lấy danh sách bài đăng
    [HttpGet]
    public async Task<IActionResult> GetPosts(
        [FromQuery] string? type,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 20;

            var query = _db.CommunityPosts
                .Where(p => !p.IsDeleted)
                .AsQueryable();

            // Lọc theo loại bài đăng
            if (!string.IsNullOrWhiteSpace(type) && Enum.TryParse<PostType>(type, true, out var postType))
            {
                query = query.Where(p => p.Type == postType);
            }

            // Tìm kiếm
            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower().Trim();
                query = query.Where(p =>
                    p.Title.ToLower().Contains(searchLower) ||
                    p.Content.ToLower().Contains(searchLower) ||
                    (p.CreatedByName != null && p.CreatedByName.ToLower().Contains(searchLower)));
            }

            var total = await query.CountAsync();

            var posts = await query
                .OrderByDescending(p => p.CreatedAtUtc)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(p => new
                {
                    p.Id,
                    Type = p.Type.ToString().ToLowerInvariant(), // Convert enum to lowercase string
                    p.Title,
                    p.Content,
                    p.CreatedById,
                    p.CreatedByName,
                    ApartmentCode = p.ApartmentCode,
                    CreatedAtUtc = p.CreatedAtUtc,
                    UpdatedAtUtc = p.UpdatedAtUtc,
                    ImageUrls = p.ImageUrls,
                    LikeCount = p.Likes.Count,
                    CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden), // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                    IsLiked = p.Likes.Any(l => l.UserId == userId),
                    SuggestionStatus = p.SuggestionStatus.HasValue ? p.SuggestionStatus.Value.ToString().ToLowerInvariant() : (string?)null,
                    CanEdit = p.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = p.CreatedById == userId || User.IsInRole("Manager")
                })
                .ToListAsync();

            return Ok(posts);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách bài đăng", message = ex.Message });
        }
    }

    // GET /api/community/posts/{id} - Lấy chi tiết bài đăng
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetPost(Guid id)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .Where(p => p.Id == id && !p.IsDeleted)
                .Select(p => new
                {
                    p.Id,
                    Type = p.Type.ToString().ToLowerInvariant(), // Convert enum to lowercase string
                    p.Title,
                    p.Content,
                    p.CreatedById,
                    p.CreatedByName,
                    ApartmentCode = p.ApartmentCode,
                    CreatedAtUtc = p.CreatedAtUtc,
                    UpdatedAtUtc = p.UpdatedAtUtc,
                    ImageUrls = p.ImageUrls,
                    LikeCount = p.Likes.Count,
                    CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden), // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                    IsLiked = p.Likes.Any(l => l.UserId == userId),
                    SuggestionStatus = p.SuggestionStatus.HasValue ? p.SuggestionStatus.Value.ToString().ToLowerInvariant() : (string?)null,
                    CanEdit = p.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = p.CreatedById == userId || User.IsInRole("Manager")
                })
                .FirstOrDefaultAsync();

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            return Ok(post);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải chi tiết bài đăng", message = ex.Message });
        }
    }

    // POST /api/community/posts - Tạo bài đăng mới
    [HttpPost]
    public async Task<IActionResult> CreatePost([FromBody] CreatePostRequest request)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return Unauthorized();

            if (string.IsNullOrWhiteSpace(request.Title))
                return BadRequest("Tiêu đề không được để trống.");

            if (string.IsNullOrWhiteSpace(request.Content))
                return BadRequest("Nội dung không được để trống.");

            if (!Enum.TryParse<PostType>(request.Type ?? "Discussion", true, out var postType))
                return BadRequest("Loại bài đăng không hợp lệ.");

            // Kiểm tra quyền: Chỉ admin/BQT được đăng TIN TỨC
            if (postType == PostType.News && !User.IsInRole("Manager") && !User.IsInRole("Security"))
            {
                return Forbid("Chỉ Ban Quản Trị mới được đăng tin tức.");
            }

            // Lấy apartment code từ user profile nếu có
            string? apartmentCode = null;
            var residentProfile = await _db.ResidentProfiles
                .Include(r => r.Apartment)
                .FirstOrDefaultAsync(r => r.UserId == userId);
            if (residentProfile != null && residentProfile.Apartment != null)
            {
                apartmentCode = residentProfile.Apartment.Code;
            }

            var post = new CommunityPost
            {
                Type = postType,
                Title = request.Title.Trim(),
                Content = request.Content.Trim(),
                CreatedById = userId,
                CreatedByName = user.FullName ?? user.UserName ?? "Ẩn danh",
                ApartmentCode = apartmentCode,
                ImageUrls = request.ImageUrls ?? new List<string>(),
                SuggestionStatus = postType == PostType.Suggestion ? SuggestionStatus.New : null
            };

            _db.CommunityPosts.Add(post);
            await _db.SaveChangesAsync();

            var result = new
            {
                post.Id,
                Type = post.Type.ToString().ToLowerInvariant(),
                post.Title,
                post.Content,
                post.CreatedById,
                post.CreatedByName,
                ApartmentCode = post.ApartmentCode,
                CreatedAtUtc = post.CreatedAtUtc,
                UpdatedAtUtc = post.UpdatedAtUtc,
                ImageUrls = post.ImageUrls,
                LikeCount = 0,
                CommentCount = 0,
                IsLiked = false,
                SuggestionStatus = post.SuggestionStatus.HasValue ? post.SuggestionStatus.Value.ToString() : (string?)null,
                CanEdit = true,
                CanDelete = true
            };

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tạo bài đăng", message = ex.Message });
        }
    }

    // PUT /api/community/posts/{id} - Cập nhật bài đăng
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdatePost(Guid id, [FromBody] UpdatePostRequest request)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            // Kiểm tra quyền: Chỉ người tạo hoặc admin mới được sửa
            var isManager = User.IsInRole("Manager") || User.IsInRole("Security");
            if (post.CreatedById != userId && !isManager)
            {
                return Forbid("Bạn không có quyền sửa bài đăng này.");
            }

            if (!string.IsNullOrWhiteSpace(request.Title))
                post.Title = request.Title.Trim();

            if (!string.IsNullOrWhiteSpace(request.Content))
                post.Content = request.Content.Trim();

            if (request.ImageUrls != null)
                post.ImageUrls = request.ImageUrls;

            await _db.SaveChangesAsync();

            var result = await _db.CommunityPosts
                .Where(p => p.Id == id)
                .Select(p => new
                {
                    p.Id,
                    Type = p.Type.ToString(),
                    p.Title,
                    p.Content,
                    p.CreatedById,
                    p.CreatedByName,
                    ApartmentCode = p.ApartmentCode,
                    CreatedAtUtc = p.CreatedAtUtc,
                    UpdatedAtUtc = p.UpdatedAtUtc,
                    ImageUrls = p.ImageUrls,
                    LikeCount = p.Likes.Count,
                    CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden), // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                    IsLiked = p.Likes.Any(l => l.UserId == userId),
                    SuggestionStatus = p.SuggestionStatus.HasValue ? p.SuggestionStatus.Value.ToString().ToLowerInvariant() : (string?)null,
                    CanEdit = p.CreatedById == userId || isManager,
                    CanDelete = p.CreatedById == userId || isManager
                })
                .FirstOrDefaultAsync();

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi cập nhật bài đăng", message = ex.Message });
        }
    }

    // DELETE /api/community/posts/{id} - Xóa bài đăng
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeletePost(Guid id)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            // Kiểm tra quyền: Chỉ người tạo hoặc admin mới được xóa
            var isManager = User.IsInRole("Manager") || User.IsInRole("Security");
            if (post.CreatedById != userId && !isManager)
            {
                return Forbid("Bạn không có quyền xóa bài đăng này.");
            }

            // Soft delete
            post.IsDeleted = true;
            await _db.SaveChangesAsync();

            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi xóa bài đăng", message = ex.Message });
        }
    }

    // POST /api/community/posts/{id}/like - Thích/Bỏ thích bài đăng
    [HttpPost("{id:guid}/like")]
    public async Task<IActionResult> ToggleLike(Guid id)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .Include(p => p.Likes)
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            var existingLike = post.Likes.FirstOrDefault(l => l.UserId == userId);

            if (existingLike != null)
            {
                // Bỏ thích
                _db.PostLikes.Remove(existingLike);
            }
            else
            {
                // Thích
                var like = new PostLike
                {
                    PostId = id,
                    UserId = userId
                };
                _db.PostLikes.Add(like);
            }

            await _db.SaveChangesAsync();

            // Lấy lại thông tin bài đăng
            var updatedPost = await _db.CommunityPosts
                .Where(p => p.Id == id)
                .Select(p => new
                {
                    p.Id,
                    Type = p.Type.ToString(),
                    p.Title,
                    p.Content,
                    p.CreatedById,
                    p.CreatedByName,
                    ApartmentCode = p.ApartmentCode,
                    CreatedAtUtc = p.CreatedAtUtc,
                    UpdatedAtUtc = p.UpdatedAtUtc,
                    ImageUrls = p.ImageUrls,
                    LikeCount = p.Likes.Count,
                    CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden), // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                    IsLiked = p.Likes.Any(l => l.UserId == userId),
                    SuggestionStatus = p.SuggestionStatus.HasValue ? p.SuggestionStatus.Value.ToString().ToLowerInvariant() : (string?)null,
                    CanEdit = p.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = p.CreatedById == userId || User.IsInRole("Manager")
                })
                .FirstOrDefaultAsync();

            return Ok(updatedPost);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi thích/bỏ thích", message = ex.Message });
        }
    }

    // PUT /api/community/posts/{id}/status - Cập nhật trạng thái kiến nghị (chỉ admin)
    [HttpPut("{id:guid}/status")]
    [Authorize(Roles = "Manager,Security")]
    public async Task<IActionResult> UpdateSuggestionStatus(Guid id, [FromBody] UpdateStatusRequest request)
    {
        try
        {
            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            if (post.Type != PostType.Suggestion)
                return BadRequest("Chỉ có thể cập nhật trạng thái cho kiến nghị.");

            if (!Enum.TryParse<SuggestionStatus>(request.Status ?? "New", true, out var status))
                return BadRequest("Trạng thái không hợp lệ.");

            post.SuggestionStatus = status;
            await _db.SaveChangesAsync();

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await _db.CommunityPosts
                .Where(p => p.Id == id)
                .Select(p => new
                {
                    p.Id,
                    Type = p.Type.ToString(),
                    p.Title,
                    p.Content,
                    p.CreatedById,
                    p.CreatedByName,
                    ApartmentCode = p.ApartmentCode,
                    CreatedAtUtc = p.CreatedAtUtc,
                    UpdatedAtUtc = p.UpdatedAtUtc,
                    ImageUrls = p.ImageUrls,
                    LikeCount = p.Likes.Count,
                    CommentCount = p.Comments.Count(c => !c.IsDeleted && !c.IsHidden), // Đếm cả comment gốc và reply, loại bỏ đã xóa và đã ẩn
                    IsLiked = p.Likes.Any(l => l.UserId == userId),
                    SuggestionStatus = p.SuggestionStatus.HasValue ? p.SuggestionStatus.Value.ToString().ToLowerInvariant() : (string?)null,
                    CanEdit = p.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = p.CreatedById == userId || User.IsInRole("Manager")
                })
                .FirstOrDefaultAsync();

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi cập nhật trạng thái", message = ex.Message });
        }
    }

    // GET /api/community/posts/{id}/comments - Lấy danh sách bình luận
    [HttpGet("{id:guid}/comments")]
    public async Task<IActionResult> GetComments(
        Guid id,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 50;

            var comments = await _db.PostComments
                .Where(c => c.PostId == id && !c.IsDeleted && !c.IsHidden && c.ParentCommentId == null) // Chỉ lấy comment gốc, không ẩn
                .OrderByDescending(c => c.CreatedAtUtc)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(c => new
                {
                    c.Id,
                    c.PostId,
                    c.ParentCommentId,
                    c.Content,
                    c.CreatedById,
                    c.CreatedByName,
                    CreatedByAvatarUrl = (string?)null, // AppUser không có AvatarUrl
                    c.CreatedAtUtc,
                    c.UpdatedAtUtc,
                    c.IsHidden,
                    LikeCount = c.Likes.Count,
                    ReplyCount = c.Replies.Count(r => !r.IsDeleted && !r.IsHidden),
                    IsLiked = c.Likes.Any(l => l.UserId == userId),
                    CanEdit = c.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = c.CreatedById == userId || User.IsInRole("Manager")
                })
                .ToListAsync();

            return Ok(comments);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải bình luận", message = ex.Message });
        }
    }

    // POST /api/community/posts/{id}/comments - Tạo bình luận hoặc reply
    [HttpPost("{id:guid}/comments")]
    public async Task<IActionResult> CreateComment(Guid id, [FromBody] CreateCommentRequest request)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            if (string.IsNullOrWhiteSpace(request.Content))
                return BadRequest("Nội dung bình luận không được để trống.");

            // Kiểm tra nếu là reply
            if (request.ParentCommentId.HasValue)
            {
                var parentComment = await _db.PostComments
                    .FirstOrDefaultAsync(c => c.Id == request.ParentCommentId.Value && c.PostId == id && !c.IsDeleted);
                if (parentComment == null)
                    return BadRequest("Không tìm thấy bình luận cha.");
            }

            var comment = new PostComment
            {
                PostId = id,
                ParentCommentId = request.ParentCommentId,
                Content = request.Content.Trim(),
                CreatedById = userId,
                CreatedByName = user.FullName ?? user.UserName ?? "Ẩn danh"
            };

            _db.PostComments.Add(comment);
            await _db.SaveChangesAsync();

            // Lấy số lượng comment mới của post (bao gồm cả reply)
            var postCommentCount = await _db.PostComments
                .CountAsync(c => c.PostId == id && !c.IsDeleted && !c.IsHidden);

            var result = new
            {
                comment.Id,
                comment.PostId,
                comment.ParentCommentId,
                comment.Content,
                comment.CreatedById,
                comment.CreatedByName,
                CreatedByAvatarUrl = (string?)null, // AppUser không có AvatarUrl
                comment.CreatedAtUtc,
                comment.UpdatedAtUtc,
                comment.IsHidden,
                LikeCount = 0,
                ReplyCount = 0,
                IsLiked = false,
                CanEdit = true,
                CanDelete = true,
                PostCommentCount = postCommentCount // Số lượng comment mới của post
            };

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tạo bình luận", message = ex.Message });
        }
    }

    // PUT /api/community/posts/{postId}/comments/{commentId} - Cập nhật bình luận
    [HttpPut("{postId:guid}/comments/{commentId:guid}")]
    public async Task<IActionResult> UpdateComment(Guid postId, Guid commentId, [FromBody] UpdateCommentRequest request)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var comment = await _db.PostComments
                .Include(c => c.Likes)
                .Include(c => c.Replies)
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId && !c.IsDeleted);

            if (comment == null) return NotFound("Không tìm thấy bình luận.");

            // Kiểm tra quyền
            var isManager = User.IsInRole("Manager") || User.IsInRole("Security");
            if (comment.CreatedById != userId && !isManager)
            {
                return Forbid("Bạn không có quyền sửa bình luận này.");
            }

            if (!string.IsNullOrWhiteSpace(request.Content))
                comment.Content = request.Content.Trim();

            await _db.SaveChangesAsync();

            var result = new
            {
                comment.Id,
                comment.PostId,
                comment.ParentCommentId,
                comment.Content,
                comment.CreatedById,
                comment.CreatedByName,
                CreatedByAvatarUrl = (string?)null, // AppUser không có AvatarUrl
                comment.CreatedAtUtc,
                comment.UpdatedAtUtc,
                comment.IsHidden,
                LikeCount = comment.Likes.Count,
                ReplyCount = comment.Replies.Count(r => !r.IsDeleted && !r.IsHidden),
                IsLiked = comment.Likes.Any(l => l.UserId == userId),
                CanEdit = comment.CreatedById == userId || isManager,
                CanDelete = comment.CreatedById == userId || isManager
            };

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi cập nhật bình luận", message = ex.Message });
        }
    }

    // DELETE /api/community/posts/{postId}/comments/{commentId} - Xóa bình luận
    [HttpDelete("{postId:guid}/comments/{commentId:guid}")]
    public async Task<IActionResult> DeleteComment(Guid postId, Guid commentId)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var comment = await _db.PostComments
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId && !c.IsDeleted);

            if (comment == null) return NotFound("Không tìm thấy bình luận.");

            // Kiểm tra quyền
            var isManager = User.IsInRole("Manager") || User.IsInRole("Security");
            if (comment.CreatedById != userId && !isManager)
            {
                return Forbid("Bạn không có quyền xóa bình luận này.");
            }

            // Nếu là admin thì ẩn, nếu là user thì xóa
            if (isManager)
            {
                comment.IsHidden = true;
            }
            else
            {
                comment.IsDeleted = true;
            }
            await _db.SaveChangesAsync();

            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi xóa bình luận", message = ex.Message });
        }
    }

    // GET /api/community/posts/{id}/likes - Lấy danh sách người đã like
    [HttpGet("{id:guid}/likes")]
    public async Task<IActionResult> GetLikes(Guid id)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var post = await _db.CommunityPosts
                .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted);

            if (post == null) return NotFound("Không tìm thấy bài đăng.");

            // Lấy danh sách người đã like
            var likeUserIds = await _db.PostLikes
                .Where(l => l.PostId == id)
                .Select(l => l.UserId)
                .Distinct()
                .ToListAsync();

            // Lấy thông tin user
            var users = await _userManager.Users
                .Where(u => likeUserIds.Contains(u.Id))
                .Select(u => new
                {
                    u.Id,
                    u.UserName,
                    u.FullName
                })
                .ToListAsync();

            var result = users.Select(u => new
            {
                u.Id,
                UserName = u.UserName ?? "Unknown",
                FullName = u.FullName ?? u.UserName ?? "Unknown",
                AvatarUrl = (string?)null // AppUser không có AvatarUrl property
            }).ToList();

            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách người like", message = ex.Message });
        }
    }

    // PUT /api/community/posts/{postId}/comments/{commentId}/hide - Ẩn bình luận (chỉ admin)
    [HttpPut("{postId:guid}/comments/{commentId:guid}/hide")]
    [Authorize(Roles = "Manager,Security")]
    public async Task<IActionResult> HideComment(Guid postId, Guid commentId)
    {
        try
        {
            var comment = await _db.PostComments
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId && !c.IsDeleted);

            if (comment == null) return NotFound("Không tìm thấy bình luận.");

            comment.IsHidden = true;
            await _db.SaveChangesAsync();

            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi ẩn bình luận", message = ex.Message });
        }
    }

    // POST /api/community/posts/{postId}/comments/{commentId}/like - Like/Unlike bình luận
    [HttpPost("{postId:guid}/comments/{commentId:guid}/like")]
    public async Task<IActionResult> ToggleCommentLike(Guid postId, Guid commentId)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var comment = await _db.PostComments
                .Include(c => c.Likes)
                .FirstOrDefaultAsync(c => c.Id == commentId && c.PostId == postId && !c.IsDeleted);

            if (comment == null) return NotFound("Không tìm thấy bình luận.");

            var existingLike = comment.Likes.FirstOrDefault(l => l.UserId == userId);

            if (existingLike != null)
            {
                // Bỏ like
                _db.PostCommentLikes.Remove(existingLike);
            }
            else
            {
                // Like
                var like = new PostCommentLike
                {
                    CommentId = commentId,
                    UserId = userId
                };
                _db.PostCommentLikes.Add(like);
            }

            await _db.SaveChangesAsync();

            // Trả về số lượng like mới
            var likeCount = await _db.PostCommentLikes.CountAsync(l => l.CommentId == commentId);
            var isLiked = await _db.PostCommentLikes.AnyAsync(l => l.CommentId == commentId && l.UserId == userId);

            return Ok(new { LikeCount = likeCount, IsLiked = isLiked });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi like bình luận", message = ex.Message });
        }
    }

    // GET /api/community/posts/{postId}/comments/{commentId}/replies - Lấy danh sách reply
    [HttpGet("{postId:guid}/comments/{commentId:guid}/replies")]
    public async Task<IActionResult> GetReplies(Guid postId, Guid commentId)
    {
        try
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var replies = await _db.PostComments
                .Where(c => c.ParentCommentId == commentId && c.PostId == postId && !c.IsDeleted && !c.IsHidden)
                .OrderBy(c => c.CreatedAtUtc)
                .Select(c => new
                {
                    c.Id,
                    c.PostId,
                    c.ParentCommentId,
                    c.Content,
                    c.CreatedById,
                    c.CreatedByName,
                    CreatedByAvatarUrl = (string?)null,
                    c.CreatedAtUtc,
                    c.UpdatedAtUtc,
                    c.IsHidden,
                    LikeCount = c.Likes.Count,
                    ReplyCount = c.Replies.Count(r => !r.IsDeleted && !r.IsHidden),
                    IsLiked = c.Likes.Any(l => l.UserId == userId),
                    CanEdit = c.CreatedById == userId || User.IsInRole("Manager"),
                    CanDelete = c.CreatedById == userId || User.IsInRole("Manager")
                })
                .ToListAsync();

            return Ok(replies);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách reply", message = ex.Message });
        }
    }

    // DTOs
    public class CreatePostRequest
    {
        public string? Type { get; set; }
        public string? Title { get; set; }
        public string? Content { get; set; }
        public List<string>? ImageUrls { get; set; }
    }

    public class UpdatePostRequest
    {
        public string? Title { get; set; }
        public string? Content { get; set; }
        public List<string>? ImageUrls { get; set; }
    }

    public class UpdateStatusRequest
    {
        public string? Status { get; set; }
    }

    public class CreateCommentRequest
    {
        public string? Content { get; set; }
        public Guid? ParentCommentId { get; set; } // ID của comment cha nếu là reply
    }

    public class UpdateCommentRequest
    {
        public string? Content { get; set; }
    }
}

