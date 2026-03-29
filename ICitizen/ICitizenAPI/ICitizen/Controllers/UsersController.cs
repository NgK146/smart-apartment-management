using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using ICitizen.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Manager")]
    public sealed class UsersController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly ILogger<UsersController> _logger;

        public UsersController(ApplicationDbContext db, UserManager<AppUser> um, RoleManager<IdentityRole> rm, ILogger<UsersController> logger)
        {
            _db = db; _userManager = um; _roleManager = rm; _logger = logger;
        }

        // ====== CREATE USER ======
        public sealed record CreateUserRequest(
            string Username,
            string Password,
            string? FullName,
            string? Email,
            string? PhoneNumber,
            List<string>? Roles
        );

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateUserRequest req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(req.Username) || string.IsNullOrWhiteSpace(req.Password))
                    return BadRequest("Username và Password là bắt buộc.");

                if (await _userManager.FindByNameAsync(req.Username) is not null)
                    return Conflict("Username đã tồn tại.");

                var user = new AppUser
                {
                    UserName = req.Username.Trim(),
                    FullName = req.FullName,
                    Email = req.Email,
                    PhoneNumber = req.PhoneNumber,
                    IsApproved = true
                };

                var result = await _userManager.CreateAsync(user, req.Password);
                if (!result.Succeeded)
                    return BadRequest(string.Join("; ", result.Errors.Select(e => e.Description)));

                if (req.Roles != null && req.Roles.Count > 0)
                {
                    foreach (var role in req.Roles.Distinct())
                    {
                        if (!await _roleManager.RoleExistsAsync(role))
                            return BadRequest($"Role không hợp lệ: {role}");
                    }
                    await _userManager.AddToRolesAsync(user, req.Roles);
                }

                return CreatedAtAction(nameof(GetUserDetails), new { username = user.UserName }, new { user.Id, user.UserName });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tạo người dùng", _logger);
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetUsers([FromQuery] int page = 1, [FromQuery] int pageSize = 50, [FromQuery] string? search = null)
        {
            try
            {
                if (page < 1) page = 1;
                if (pageSize < 1 || pageSize > 200) pageSize = 50;

                var q = _db.Users.AsQueryable();
                if (!string.IsNullOrWhiteSpace(search))
                {
                    search = search.ToLower().Trim();
                    q = q.Where(u =>
                        (u.UserName ?? "").ToLower().Contains(search) ||
                        (u.FullName ?? "").ToLower().Contains(search) ||
                        (u.Email ?? "").ToLower().Contains(search));
                }

                var total = await q.CountAsync();
                var items = await q
                    .OrderByDescending(u => u.Id)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .Select(u => new
                    {
                        id = u.Id,
                        username = u.UserName,
                        fullName = u.FullName,
                        email = u.Email,
                        phoneNumber = u.PhoneNumber,
                        isApproved = u.IsApproved,
                        requestedRole = u.RequestedRole
                    })
                    .ToListAsync();

                return Ok(new { page, pageSize, total, items });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tải danh sách người dùng", _logger);
            }
        }

        // ====== UPDATE USER ======
        public sealed record UpdateUserRequest(
            string? FullName,
            string? Email,
            string? PhoneNumber,
            bool? IsApproved,
            List<string>? Roles
        );

        [HttpPut("{username}")]
        public async Task<IActionResult> Update(string username, [FromBody] UpdateUserRequest req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(username))
                    return BadRequest("Username không được để trống.");

                var user = await _userManager.FindByNameAsync(username);
                if (user == null) return NotFound("Không tìm thấy người dùng.");

                if (!string.IsNullOrWhiteSpace(req.FullName)) user.FullName = req.FullName;
                if (!string.IsNullOrWhiteSpace(req.Email)) user.Email = req.Email;
                if (!string.IsNullOrWhiteSpace(req.PhoneNumber)) user.PhoneNumber = req.PhoneNumber;
                if (req.IsApproved.HasValue) user.IsApproved = req.IsApproved.Value;

                var upd = await _userManager.UpdateAsync(user);
                if (!upd.Succeeded)
                    return BadRequest(string.Join("; ", upd.Errors.Select(e => e.Description)));

                // Update roles if provided (replace all)
                if (req.Roles != null)
                {
                    foreach (var role in req.Roles.Distinct())
                    {
                        if (!await _roleManager.RoleExistsAsync(role))
                            return BadRequest($"Role không hợp lệ: {role}");
                    }
                    var currentRoles = await _userManager.GetRolesAsync(user);
                    var toRemove = currentRoles.Where(cr => !req.Roles.Contains(cr)).ToList();
                    if (toRemove.Count > 0) await _userManager.RemoveFromRolesAsync(user, toRemove);
                    var toAdd = req.Roles.Where(r => !currentRoles.Contains(r)).ToList();
                    if (toAdd.Count > 0) await _userManager.AddToRolesAsync(user, toAdd);
                }

                return NoContent();
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi cập nhật người dùng", _logger);
            }
        }

        [HttpPost("{username}/approve")]
        public async Task<IActionResult> Approve(string username)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(username))
                    return BadRequest("Username không được để trống.");

                var user = await _userManager.FindByNameAsync(username);
                if (user == null) return NotFound("Không tìm thấy người dùng.");

                user.IsApproved = true;
                var result = await _userManager.UpdateAsync(user);
                if (!result.Succeeded)
                    return BadRequest(string.Join("; ", result.Errors.Select(e => e.Description)));

                return Ok("Đã duyệt tài khoản.");
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi duyệt tài khoản", _logger);
            }
        }

        [HttpPost("{username}/role/{role}")]
        public async Task<IActionResult> AssignRole(string username, string role)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(role))
                    return BadRequest("Username và Role không được để trống.");

                var user = await _userManager.FindByNameAsync(username);
                if (user == null) return NotFound("Không tìm thấy người dùng.");

                if (!await _roleManager.RoleExistsAsync(role))
                    return BadRequest($"Role không hợp lệ: {role}");

                var currentRoles = await _userManager.GetRolesAsync(user);
                if (!currentRoles.Contains(role))
                {
                    var result = await _userManager.AddToRoleAsync(user, role);
                    if (!result.Succeeded)
                        return BadRequest(string.Join("; ", result.Errors.Select(e => e.Description)));
                }

                return Ok($"Đã gán role {role} cho {username}.");
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi gán role", _logger);
            }
        }

        // ====== DELETE USER ======
        [HttpDelete("{username}")]
        public async Task<IActionResult> Delete(string username)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(username))
                    return BadRequest("Username không được để trống.");

                var user = await _userManager.FindByNameAsync(username);
                if (user == null) return NotFound("Không tìm thấy người dùng.");

                // Xóa ResidentProfile nếu có
                try
                {
                    var profiles = _db.ResidentProfiles.Where(r => r.UserId == user.Id);
                    if (await profiles.AnyAsync())
                    {
                        _db.ResidentProfiles.RemoveRange(profiles);
                        await _db.SaveChangesAsync();
                    }
                }
                catch
                {
                    // Nếu có lỗi khi xóa profile, vẫn tiếp tục xóa user
                }

                var res = await _userManager.DeleteAsync(user);
                if (!res.Succeeded)
                    return BadRequest(string.Join("; ", res.Errors.Select(e => e.Description)));

                return NoContent();
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi xóa người dùng", _logger);
            }
        }

        [HttpGet("{username}/details")]
        public async Task<IActionResult> GetUserDetails(string username)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(username))
                    return BadRequest("Username không được để trống.");

                var user = await _userManager.FindByNameAsync(username);
                if (user == null) return NotFound("Không tìm thấy người dùng.");

                var roles = await _userManager.GetRolesAsync(user);
                
                // Lấy ResidentProfile nếu có (với null safety)
                ResidentProfile? residentProfile = null;
                try
                {
                    residentProfile = await _db.ResidentProfiles
                        .Include(r => r.Apartment)
                        .FirstOrDefaultAsync(r => r.UserId == user.Id);
                }
                catch
                {
                    // Nếu có lỗi khi load ResidentProfile, bỏ qua và tiếp tục
                }

                var result = new
                {
                    id = user.Id,
                    username = user.UserName,
                    fullName = user.FullName,
                    email = user.Email,
                    phoneNumber = user.PhoneNumber,
                    isApproved = user.IsApproved,
                    requestedRole = user.RequestedRole,
                    roles = roles,
                    createdAtUtc = user.CreatedAtUtc,
                    residentProfile = residentProfile != null ? new
                    {
                        id = residentProfile.Id,
                        nationalId = residentProfile.NationalId,
                        phone = residentProfile.Phone,
                        email = residentProfile.Email,
                        residentType = residentProfile.ResidentType,
                        numResidents = residentProfile.NumResidents,
                        isVerifiedByBQL = residentProfile.IsVerifiedByBQL,
                        dateJoined = residentProfile.DateJoined,
                        apartment = residentProfile.Apartment != null ? new
                        {
                            id = residentProfile.Apartment.Id,
                            code = residentProfile.Apartment.Code,
                            building = residentProfile.Apartment.Building,
                            floor = residentProfile.Apartment.Floor,
                            areaM2 = residentProfile.Apartment.AreaM2
                        } : null
                    } : null
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tải chi tiết người dùng", _logger);
            }
        }
    }
}
