using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ResidentsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly ILogger<ResidentsController> _logger;
    
    public ResidentsController(ApplicationDbContext db, ILogger<ResidentsController> logger)
    {
        _db = db;
        _logger = logger;
    }

    // Ban quản lý quản lý hồ sơ cư dân & gán căn hộ. :contentReference[oaicite:13]{index=13}
    [HttpGet]
    [Authorize(Roles = "Manager")]
    public async Task<PagedResult<ResidentProfile>> List([FromQuery] QueryParameters p, [FromQuery] bool? pendingOnly = null)
    {
        var q = _db.ResidentProfiles.Include(r => r.Apartment).AsQueryable();
        if (pendingOnly == true)
            q = q.Where(x => !x.IsVerifiedByBQL); // Chỉ lấy các yêu cầu chờ duyệt
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(x => (x.Phone ?? "").Contains(p.Search) || (x.Email ?? "").Contains(p.Search) || (x.NationalId ?? "").Contains(p.Search) || x.Apartment!.Code.Contains(p.Search));
        return await q.OrderByDescending(x => x.CreatedAtUtc).ToPagedResultAsync(p.Page, p.PageSize);
    }

    // Lấy danh sách yêu cầu liên kết căn hộ chờ duyệt (có thông tin User)
    [HttpGet("pending")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> GetPendingRequests([FromQuery] QueryParameters p)
    {
        try
        {
            var q = _db.ResidentProfiles
                .Include(r => r.Apartment)
                .Where(x => !x.IsVerifiedByBQL)
                .AsQueryable();
            
            if (!string.IsNullOrWhiteSpace(p.Search))
                q = q.Where(x => (x.Phone ?? "").Contains(p.Search) || (x.Email ?? "").Contains(p.Search) || (x.NationalId ?? "").Contains(p.Search) || (x.Apartment != null && x.Apartment.Code.Contains(p.Search)));
            
            var total = await q.CountAsync();
            var items = await q
                .OrderByDescending(x => x.CreatedAtUtc)
                .Skip((p.Page - 1) * p.PageSize)
                .Take(p.PageSize)
                .Select(r => new
                {
                    r.Id,
                    r.UserId,
                    r.NationalId,
                    r.Phone,
                    r.Email,
                    r.DateJoined,
                    r.ResidentType,
                    r.NumResidents,
                    Apartment = r.Apartment != null ? new { r.Apartment.Id, r.Apartment.Code, r.Apartment.Building, r.Apartment.Floor } : null,
                    CreatedAtUtc = r.CreatedAtUtc
                })
                .ToListAsync();
            
            return Ok(new { page = p.Page, pageSize = p.PageSize, total, items });
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi tải danh sách yêu cầu liên kết căn hộ", _logger);
        }
    }

    // Cư dân tự xem/ cập nhật hồ sơ của mình
    [HttpGet("me")]
    [Authorize] // Cho phép tất cả user đã đăng nhập, kiểm tra quyền bên trong
    public async Task<ActionResult<ResidentProfile?>> MyProfile()
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized("Người dùng chưa đăng nhập.");

        // Kiểm tra quyền: Manager/Security/Vendor hoặc có ResidentProfile
        var isManager = User.IsInRole("Manager");
        var isSecurity = User.IsInRole("Security");
        var isVendor = User.IsInRole("Vendor");
        
        var profile = await _db.ResidentProfiles
            .Include(r => r.Apartment)
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == uid);

        if (profile is null)
        {
            return NotFound("Không tìm thấy hồ sơ cư dân.");
        }

        return Ok(MapProfile(profile));
    }

    // Cư dân tự liên kết căn hộ - Cho phép cả user chưa có role (mới đăng ký)
    [HttpPost("me/link-apartment")]
    [Authorize] // Cho phép tất cả user đã đăng nhập
    public async Task<IActionResult> LinkApartment([FromBody] LinkApartmentRequest request)
    {
        try
        {
            // Validation
            if (request == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            if (string.IsNullOrWhiteSpace(request.ApartmentCode))
                return BadRequest(new { error = "Mã căn hộ là bắt buộc" });
            
            var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrWhiteSpace(uid)) return Unauthorized();

            // Tìm căn hộ theo mã
            var apartment = await _db.Apartments.FirstOrDefaultAsync(a => a.Code == request.ApartmentCode);
            if (apartment == null) return BadRequest(new { error = "Mã căn hộ không tồn tại" });

        // Tìm hoặc tạo ResidentProfile
        var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
        if (profile == null)
        {
            // Tạo mới ResidentProfile nếu chưa có
            profile = new ResidentProfile
            {
                UserId = uid,
                ApartmentId = apartment.Id,
                NationalId = request.NationalId,
                Phone = request.Phone,
                Email = request.Email,
                IsVerifiedByBQL = false, // Chờ duyệt
                DateJoined = DateTime.UtcNow
            };
            _db.ResidentProfiles.Add(profile);
        }
        else
        {
            // Cập nhật căn hộ nếu đã có profile
            profile.ApartmentId = apartment.Id;
            if (!string.IsNullOrWhiteSpace(request.NationalId)) profile.NationalId = request.NationalId;
            if (!string.IsNullOrWhiteSpace(request.Phone)) profile.Phone = request.Phone;
            if (!string.IsNullOrWhiteSpace(request.Email)) profile.Email = request.Email;
            profile.IsVerifiedByBQL = false; // Reset trạng thái duyệt khi đổi căn hộ
        }

            await _db.SaveChangesAsync();
            return Ok(new { message = "Đã gửi yêu cầu liên kết căn hộ. Vui lòng chờ Ban quản lý duyệt.", apartmentCode = apartment.Code });
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi liên kết căn hộ", _logger);
        }
    }

    public record LinkApartmentRequest(string ApartmentCode, string? NationalId, string? Phone, string? Email);

    // Admin duyệt yêu cầu liên kết căn hộ
    [HttpPut("{id}/approve")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Approve(Guid id)
    {
        try
        {
            var profile = await _db.ResidentProfiles.Include(r => r.Apartment).FirstOrDefaultAsync(r => r.Id == id);
            if (profile == null) return NotFound(new { error = "Không tìm thấy hồ sơ cư dân" });
            
            profile.IsVerifiedByBQL = true;
            
            // Tự động cập nhật status căn hộ thành Occupied khi được duyệt
            // Chỉ cập nhật nếu status hiện tại là Available (không động vào Maintenance/Reserved)
            if (profile.Apartment != null && profile.Apartment.Status == ApartmentStatus.Available)
            {
                profile.Apartment.Status = ApartmentStatus.Occupied;
            }
            
            await _db.SaveChangesAsync();
            return NoContent();
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi duyệt hồ sơ cư dân", _logger);
        }
    }

    // Admin từ chối yêu cầu liên kết căn hộ
    [HttpPut("{id}/reject")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Reject(Guid id)
    {
        try
        {
            var profile = await _db.ResidentProfiles.Include(r => r.Apartment).FirstOrDefaultAsync(r => r.Id == id);
            if (profile == null) return NotFound(new { error = "Không tìm thấy hồ sơ cư dân" });
            
            var apartmentId = profile.ApartmentId;
            
            // Xóa ResidentProfile khi từ chối
            _db.ResidentProfiles.Remove(profile);
            
            // Nếu căn hộ không còn ResidentProfile nào được verify, đặt lại status về Available
            if (apartmentId != Guid.Empty)
            {
                var apartment = await _db.Apartments.Include(a => a.Residents).FirstOrDefaultAsync(a => a.Id == apartmentId);
                if (apartment != null && !apartment.Residents.Any(r => r.IsVerifiedByBQL))
                {
                    // Chỉ đặt về Available nếu status là Occupied (không động vào Maintenance/Reserved)
                    if (apartment.Status == ApartmentStatus.Occupied)
                    {
                        apartment.Status = ApartmentStatus.Available;
                    }
                }
            }
            
            await _db.SaveChangesAsync();
            return NoContent();
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi từ chối hồ sơ cư dân", _logger);
        }
    }

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Create(ResidentProfile m)
    {
        try
        {
            // Validation
            if (m == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            if (string.IsNullOrWhiteSpace(m.UserId))
                return BadRequest(new { error = "UserId là bắt buộc" });
            
            // Kiểm tra UserId có tồn tại không
            var userExists = await _db.Users.AnyAsync(u => u.Id == m.UserId);
            if (!userExists)
                return BadRequest(new { error = "UserId không tồn tại" });
            
            // Nếu có ApartmentId, kiểm tra căn hộ có tồn tại không
            if (m.ApartmentId != Guid.Empty)
            {
                var apartmentExists = await _db.Apartments.AnyAsync(a => a.Id == m.ApartmentId);
                if (!apartmentExists)
                    return BadRequest(new { error = "Căn hộ không tồn tại" });
            }
            
            _db.ResidentProfiles.Add(m);
            await _db.SaveChangesAsync();
            return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi tạo hồ sơ cư dân", _logger);
        }
    }

    [HttpGet("{id}")]
    [Authorize]
    public async Task<ActionResult<ResidentProfile>> Get(Guid id)
    {
        var m = await _db.ResidentProfiles.Include(r => r.Apartment).FirstOrDefaultAsync(x => x.Id == id);
        return m is null ? NotFound() : m;
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, ResidentProfile m)
    {
        try
        {
            if (m == null)
                return BadRequest(new { error = "Dữ liệu không hợp lệ" });
            
            var dbm = await _db.ResidentProfiles.FindAsync(id);
            if (dbm is null) return NotFound(new { error = "Không tìm thấy hồ sơ cư dân" });
            
            // Validation
            if (!string.IsNullOrWhiteSpace(m.UserId))
            {
                var userExists = await _db.Users.AnyAsync(u => u.Id == m.UserId);
                if (!userExists)
                    return BadRequest(new { error = "UserId không tồn tại" });
                dbm.UserId = m.UserId;
            }
            
            if (m.ApartmentId != Guid.Empty)
            {
                var apartmentExists = await _db.Apartments.AnyAsync(a => a.Id == m.ApartmentId);
                if (!apartmentExists)
                    return BadRequest(new { error = "Căn hộ không tồn tại" });
                dbm.ApartmentId = m.ApartmentId;
            }
            
            dbm.NationalId = m.NationalId;
            dbm.Phone = m.Phone;
            dbm.Email = m.Email;
            
            await _db.SaveChangesAsync();
            return NoContent();
        }
        catch (Exception ex)
        {
            return ApiResponseHelper.HandleException(ex, "Lỗi khi cập nhật hồ sơ cư dân", _logger);
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.ResidentProfiles.FindAsync(id);
        if (m is null) return NotFound();
        _db.ResidentProfiles.Remove(m); await _db.SaveChangesAsync(); return NoContent();
    }

    private static object MapProfile(ResidentProfile profile)
        => new
        {
            profile.Id,
            profile.UserId,
            profile.NationalId,
            profile.Phone,
            profile.Email,
            profile.DateJoined,
            profile.NumResidents,
            profile.ResidentType,
            profile.IsVerifiedByBQL,
            profile.ApartmentId,
            Apartment = profile.Apartment == null ? null : new
            {
                profile.Apartment.Id,
                profile.Apartment.Code,
                profile.Apartment.Building,
                profile.Apartment.Floor,
                profile.Apartment.AreaM2,
                profile.Apartment.Status
            }
        };
}
