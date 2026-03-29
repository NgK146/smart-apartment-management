using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ICitizen.Domain;
using ICitizen.Data;
using ICitizen.Common;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class VisitorController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<VisitorController> _logger;

        public VisitorController(
            ApplicationDbContext context,
            ILogger<VisitorController> logger)
        {
            _context = context;
            _logger = logger;
        }

        private string GetCurrentUserId()
        {
            // Dùng ClaimTypes.NameIdentifier (đã được thêm vào JWT token)
            var userId = User?.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User?.FindFirst("sub")?.Value;

            if (string.IsNullOrEmpty(userId))
            {
                _logger.LogWarning("User not authenticated when accessing VisitorController. Claims: {Claims}", 
                    string.Join(", ", User?.Claims.Select(c => $"{c.Type}={c.Value}") ?? Enumerable.Empty<string>()));
                throw new UnauthorizedAccessException("User not authenticated");
            }

            return userId;
        }

        /// <summary>
        /// Tạo visitor access và generate QR code
        /// </summary>
        [HttpPost("create")]
        public async Task<IActionResult> CreateVisitorAccess([FromBody] CreateVisitorAccessRequest request)
        {
            try
            {
                if (request == null)
                    return BadRequest(new { error = "Request không hợp lệ" });

                if (string.IsNullOrWhiteSpace(request.VisitorName))
                    return BadRequest(new { error = "Tên khách là bắt buộc" });

                var userId = GetCurrentUserId();
                var resident = await _context.ResidentProfiles
                    .Include(r => r.Apartment)
                    .FirstOrDefaultAsync(r => r.UserId == userId);

                if (resident == null)
                    return NotFound(new { error = "Không tìm thấy thông tin cư dân" });

                // Generate QR code sử dụng helper
                var qrCode = QRCodeHelper.GenerateVisitorQRCode();

                var visitDate = request.VisitDate ?? DateTime.Now;
                var expiresAt = visitDate.AddDays(1); // QR code hết hạn sau 1 ngày

                var visitorAccess = new VisitorAccess
                {
                    Id = Guid.NewGuid(),
                    ResidentId = resident.Id,
                    ApartmentCode = resident.Apartment?.Code ?? "UNKNOWN",
                    VisitorName = request.VisitorName,
                    VisitorPhone = request.VisitorPhone,
                    VisitorEmail = request.VisitorEmail,
                    VisitDate = visitDate,
                    VisitTime = request.VisitTime,
                    Purpose = request.Purpose,
                    QrCode = qrCode,
                    QrCodeUrl = $"{Request.Scheme}://{Request.Host}/api/Visitor/validate-qr?code={qrCode}",
                    Status = "pending",
                    CreatedAt = DateTime.UtcNow,
                    ExpiresAt = expiresAt
                };

                _context.VisitorAccesses.Add(visitorAccess);
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    id = visitorAccess.Id,
                    residentId = visitorAccess.ResidentId,
                    apartmentCode = visitorAccess.ApartmentCode,
                    visitorName = visitorAccess.VisitorName,
                    visitorPhone = visitorAccess.VisitorPhone,
                    visitorEmail = visitorAccess.VisitorEmail,
                    visitDate = visitorAccess.VisitDate,
                    visitTime = visitorAccess.VisitTime,
                    purpose = visitorAccess.Purpose,
                    qrCode = visitorAccess.QrCode,
                    qrCodeUrl = visitorAccess.QrCodeUrl,
                    status = visitorAccess.Status,
                    createdAt = visitorAccess.CreatedAt,
                    expiresAt = visitorAccess.ExpiresAt
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tạo visitor access", _logger);
            }
        }

        /// <summary>
        /// Lấy danh sách visitor của cư dân
        /// </summary>
        [HttpGet("my-visitors")]
        public async Task<IActionResult> GetMyVisitors([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
        {
            try
            {
                var userId = GetCurrentUserId();
                var resident = await _context.ResidentProfiles
                    .FirstOrDefaultAsync(r => r.UserId == userId);

                if (resident == null)
                    return Ok(new { items = new List<object>(), total = 0, page, pageSize });

                var query = _context.VisitorAccesses
                    .Where(v => v.ResidentId == resident.Id)
                    .OrderByDescending(v => v.CreatedAt);

                var total = await query.CountAsync();
                var items = await query
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .Select(v => new
                    {
                        id = v.Id,
                        residentId = v.ResidentId,
                        apartmentCode = v.ApartmentCode,
                        visitorName = v.VisitorName,
                        visitorPhone = v.VisitorPhone,
                        visitorEmail = v.VisitorEmail,
                        visitDate = v.VisitDate,
                        visitTime = v.VisitTime,
                        purpose = v.Purpose,
                        qrCode = v.QrCode,
                        qrCodeUrl = v.QrCodeUrl,
                        status = v.Status,
                        checkedInAt = v.CheckedInAt,
                        checkedOutAt = v.CheckedOutAt,
                        createdAt = v.CreatedAt,
                        expiresAt = v.ExpiresAt
                    })
                    .ToListAsync();

                return Ok(new { items, total, page, pageSize });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi lấy danh sách visitor", _logger);
            }
        }

        /// <summary>
        /// Validate QR code (dùng khi scan QR)
        /// </summary>
        [HttpPost("validate-qr")]
        [AllowAnonymous] // Cho phép scan QR mà không cần đăng nhập
        public async Task<IActionResult> ValidateQRCode([FromBody] ValidateQRRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.QrCode))
                    return BadRequest(new { error = "QR code không hợp lệ" });

                var visitorAccess = await _context.VisitorAccesses
                    .FirstOrDefaultAsync(v => v.QrCode == request.QrCode);

                if (visitorAccess == null)
                    return NotFound(new { error = "QR code không tồn tại hoặc đã hết hạn" });

                if (visitorAccess.ExpiresAt < DateTime.UtcNow)
                {
                    visitorAccess.Status = "expired";
                    await _context.SaveChangesAsync();
                    return BadRequest(new { error = "QR code đã hết hạn" });
                }

                return Ok(new
                {
                    id = visitorAccess.Id,
                    residentId = visitorAccess.ResidentId,
                    apartmentCode = visitorAccess.ApartmentCode,
                    visitorName = visitorAccess.VisitorName,
                    visitorPhone = visitorAccess.VisitorPhone,
                    visitorEmail = visitorAccess.VisitorEmail,
                    visitDate = visitorAccess.VisitDate,
                    visitTime = visitorAccess.VisitTime,
                    purpose = visitorAccess.Purpose,
                    qrCode = visitorAccess.QrCode,
                    qrCodeUrl = visitorAccess.QrCodeUrl,
                    status = visitorAccess.Status,
                    checkedInAt = visitorAccess.CheckedInAt,
                    checkedOutAt = visitorAccess.CheckedOutAt,
                    createdAt = visitorAccess.CreatedAt,
                    expiresAt = visitorAccess.ExpiresAt
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi validate QR code", _logger);
            }
        }

        /// <summary>
        /// Check-in visitor bằng QR code
        /// </summary>
        [HttpPost("check-in")]
        [Authorize(Roles = "Manager,Security")] // Chỉ Manager và Security mới check-in được
        public async Task<IActionResult> CheckInVisitor([FromBody] ValidateQRRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.QrCode))
                    return BadRequest(new { error = "QR code không hợp lệ" });

                var visitorAccess = await _context.VisitorAccesses
                    .FirstOrDefaultAsync(v => v.QrCode == request.QrCode);

                if (visitorAccess == null)
                    return NotFound(new { error = "QR code không tồn tại" });

                if (visitorAccess.ExpiresAt < DateTime.UtcNow)
                    return BadRequest(new { error = "QR code đã hết hạn" });

                if (visitorAccess.Status != "pending")
                    return BadRequest(new { error = $"QR code đã được sử dụng. Trạng thái: {visitorAccess.Status}" });

                visitorAccess.Status = "checkedIn";
                visitorAccess.CheckedInAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    id = visitorAccess.Id,
                    status = visitorAccess.Status,
                    checkedInAt = visitorAccess.CheckedInAt,
                    message = "Check-in thành công"
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi check-in visitor", _logger);
            }
        }

        /// <summary>
        /// Check-out visitor
        /// </summary>
        [HttpPost("{id}/check-out")]
        [Authorize(Roles = "Manager,Security")]
        public async Task<IActionResult> CheckOutVisitor(Guid id)
        {
            try
            {
                var visitorAccess = await _context.VisitorAccesses.FindAsync(id);
                if (visitorAccess == null)
                    return NotFound(new { error = "Không tìm thấy visitor access" });

                if (visitorAccess.Status != "checkedIn")
                    return BadRequest(new { error = "Visitor chưa check-in" });

                visitorAccess.Status = "checkedOut";
                visitorAccess.CheckedOutAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    id = visitorAccess.Id,
                    status = visitorAccess.Status,
                    checkedOutAt = visitorAccess.CheckedOutAt,
                    message = "Check-out thành công"
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi check-out visitor", _logger);
            }
        }

        /// <summary>
        /// Hủy visitor access
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> CancelVisitor(Guid id)
        {
            try
            {
                var userId = GetCurrentUserId();
                var resident = await _context.ResidentProfiles
                    .FirstOrDefaultAsync(r => r.UserId == userId);

                var visitorAccess = await _context.VisitorAccesses.FindAsync(id);
                if (visitorAccess == null)
                    return NotFound(new { error = "Không tìm thấy visitor access" });

                // Admin có thể hủy bất kỳ visitor nào
                var isManager = User.IsInRole("Manager");
                if (!isManager && visitorAccess.ResidentId != resident?.Id)
                    return BadRequest(new { error = "Bạn không có quyền hủy visitor access này" });

                visitorAccess.Status = "cancelled";
                await _context.SaveChangesAsync();

                return Ok(new { message = "Đã hủy visitor access" });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi hủy visitor access", _logger);
            }
        }

        /// <summary>
        /// Admin: Lấy tất cả visitor accesses (có phân trang và filter)
        /// </summary>
        [HttpGet("admin/all")]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> GetAllVisitors(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? search = null,
            [FromQuery] string? status = null)
        {
            try
            {
                var query = _context.VisitorAccesses
                    .Include(v => v.Resident)
                        .ThenInclude(r => r.Apartment)
                    .AsQueryable();

                // Filter by status
                if (!string.IsNullOrWhiteSpace(status))
                {
                    query = query.Where(v => v.Status == status.ToLower());
                }

                // Search by name, phone, apartment code
                if (!string.IsNullOrWhiteSpace(search))
                {
                    var searchLower = search.ToLower();
                    query = query.Where(v =>
                        v.VisitorName.ToLower().Contains(searchLower) ||
                        (v.VisitorPhone != null && v.VisitorPhone.Contains(search)) ||
                        (v.ApartmentCode != null && v.ApartmentCode.Contains(searchLower)));
                }

                var total = await query.CountAsync();
                var items = await query
                    .OrderByDescending(v => v.CreatedAt)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .Select(v => new
                    {
                        id = v.Id,
                        residentId = v.ResidentId,
                        apartmentCode = v.ApartmentCode,
                        visitorName = v.VisitorName,
                        visitorPhone = v.VisitorPhone,
                        visitorEmail = v.VisitorEmail,
                        visitDate = v.VisitDate,
                        visitTime = v.VisitTime,
                        purpose = v.Purpose,
                        qrCode = v.QrCode,
                        qrCodeUrl = v.QrCodeUrl,
                        status = v.Status,
                        checkedInAt = v.CheckedInAt,
                        checkedOutAt = v.CheckedOutAt,
                        createdAt = v.CreatedAt,
                        expiresAt = v.ExpiresAt,
                        residentName = v.Resident != null ? v.Resident.UserId : null
                    })
                    .ToListAsync();

                return Ok(new { items, total, page, pageSize });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi lấy danh sách visitor", _logger);
            }
        }

        /// <summary>
        /// Admin: Tạo visitor access cho cư dân cụ thể
        /// </summary>
        [HttpPost("admin/create")]
        [Authorize(Roles = "Manager")]
        public async Task<IActionResult> CreateVisitorForResident([FromBody] CreateVisitorForResidentRequest request)
        {
            try
            {
                if (request == null)
                    return BadRequest(new { error = "Request không hợp lệ" });

                if (string.IsNullOrWhiteSpace(request.VisitorName))
                    return BadRequest(new { error = "Tên khách là bắt buộc" });

                if (string.IsNullOrWhiteSpace(request.ResidentId))
                    return BadRequest(new { error = "Resident ID hoặc Apartment ID là bắt buộc" });

                // Tìm resident - có thể là ResidentProfile.Id hoặc ApartmentId
                var residentIdGuid = Guid.Parse(request.ResidentId);
                var resident = await _context.ResidentProfiles
                    .Include(r => r.Apartment)
                    .FirstOrDefaultAsync(r => r.Id == residentIdGuid || r.ApartmentId == residentIdGuid);

                if (resident == null)
                    return NotFound(new { error = "Không tìm thấy cư dân cho căn hộ này" });

                // Generate QR code
                var qrCode = QRCodeHelper.GenerateVisitorQRCode();

                var visitDate = request.VisitDate ?? DateTime.Now;
                var expiresAt = visitDate.AddDays(1);

                var visitorAccess = new VisitorAccess
                {
                    Id = Guid.NewGuid(),
                    ResidentId = resident.Id,
                    ApartmentCode = request.ApartmentCode ?? resident.Apartment?.Code ?? "UNKNOWN",
                    VisitorName = request.VisitorName,
                    VisitorPhone = request.VisitorPhone,
                    VisitorEmail = request.VisitorEmail,
                    VisitDate = visitDate,
                    VisitTime = request.VisitTime,
                    Purpose = request.Purpose,
                    QrCode = qrCode,
                    QrCodeUrl = $"{Request.Scheme}://{Request.Host}/api/Visitor/validate-qr?code={qrCode}",
                    Status = "pending",
                    CreatedAt = DateTime.UtcNow,
                    ExpiresAt = expiresAt
                };

                _context.VisitorAccesses.Add(visitorAccess);
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    id = visitorAccess.Id,
                    residentId = visitorAccess.ResidentId,
                    apartmentCode = visitorAccess.ApartmentCode,
                    visitorName = visitorAccess.VisitorName,
                    visitorPhone = visitorAccess.VisitorPhone,
                    visitorEmail = visitorAccess.VisitorEmail,
                    visitDate = visitorAccess.VisitDate,
                    visitTime = visitorAccess.VisitTime,
                    purpose = visitorAccess.Purpose,
                    qrCode = visitorAccess.QrCode,
                    qrCodeUrl = visitorAccess.QrCodeUrl,
                    status = visitorAccess.Status,
                    createdAt = visitorAccess.CreatedAt,
                    expiresAt = visitorAccess.ExpiresAt
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tạo visitor access", _logger);
            }
        }
    }

    public class CreateVisitorAccessRequest
    {
        public string VisitorName { get; set; } = string.Empty;
        public string? VisitorPhone { get; set; }
        public string? VisitorEmail { get; set; }
        public DateTime? VisitDate { get; set; }
        public string? VisitTime { get; set; }
        public string? Purpose { get; set; }
    }

    public class ValidateQRRequest
    {
        public string QrCode { get; set; } = string.Empty;
    }

    public class CreateVisitorForResidentRequest
    {
        public string ResidentId { get; set; } = string.Empty;
        public string? ApartmentCode { get; set; }
        public string VisitorName { get; set; } = string.Empty;
        public string? VisitorPhone { get; set; }
        public string? VisitorEmail { get; set; }
        public DateTime? VisitDate { get; set; }
        public string? VisitTime { get; set; }
        public string? Purpose { get; set; }
    }
}

