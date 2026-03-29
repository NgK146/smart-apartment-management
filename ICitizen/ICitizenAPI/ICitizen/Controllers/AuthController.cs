using ICitizen.Auth;
using ICitizen.Models;
using ICitizen.Domain;
using ICitizen.Common;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using System.Security.Cryptography;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<AppUser> _userManager;
        private readonly SignInManager<AppUser> _signInManager;
        private readonly IJwtTokenService _tokenService;
        private readonly IMemoryCache _cache;
        private readonly ILogger<AuthController> _logger;
        private readonly IEmailSender _emailSender;

        // Rate limiting settings
        private const int MAX_LOGIN_ATTEMPTS = 5;
        private const int LOCKOUT_DURATION_MINUTES = 15;

        public AuthController(UserManager<AppUser> userManager,
                              SignInManager<AppUser> signInManager,
                              IJwtTokenService tokenService,
                              IMemoryCache cache,
                              ILogger<AuthController> logger,
                              IEmailSender emailSender)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _tokenService = tokenService;
            _cache = cache;
            _logger = logger;
            _emailSender = emailSender;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest model)
        {
            try
            {
                // Validation
                if (model == null)
                    return BadRequest(new { error = "Dữ liệu không hợp lệ" });
                
                if (string.IsNullOrWhiteSpace(model.Username))
                    return BadRequest(new { error = "Tên đăng nhập là bắt buộc" });
                
                if (string.IsNullOrWhiteSpace(model.Password))
                    return BadRequest(new { error = "Mật khẩu là bắt buộc" });
                
                if (model.Password.Length < 6)
                    return BadRequest(new { error = "Mật khẩu phải có ít nhất 6 ký tự" });
                
                // Email validation (nếu có)
                if (!string.IsNullOrWhiteSpace(model.Email))
                {
                    var emailRegex = new System.Text.RegularExpressions.Regex(@"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
                    if (!emailRegex.IsMatch(model.Email))
                        return BadRequest(new { error = "Email không hợp lệ" });
                }
                
                var exists = await _userManager.FindByNameAsync(model.Username);
                if (exists != null) return Conflict(new { error = "Username đã tồn tại" });

            var user = new AppUser
            {
                UserName = model.Username,
                Email = model.Email,
                FullName = model.FullName,
                PhoneNumber = model.PhoneNumber,
                IsApproved = false,
                RequestedRole = model.DesiredRole
            };

            var result = await _userManager.CreateAsync(user, model.Password);
            if (!result.Succeeded)
                return BadRequest(string.Join("; ", result.Errors.Select(e => e.Description)));

            // Nếu là Resident và có đầy đủ thông tin liên kết căn hộ → Tự động tạo ResidentProfile
            if (model.DesiredRole == "Resident" && !string.IsNullOrWhiteSpace(model.ApartmentCode) && !string.IsNullOrWhiteSpace(model.NationalId))
            {
                var apt = HttpContext.RequestServices.GetService(typeof(ICitizen.Data.ApplicationDbContext)) as ICitizen.Data.ApplicationDbContext;
                if (apt != null)
                {
                    var apartment = await apt.Apartments.FirstOrDefaultAsync(a => a.Code == model.ApartmentCode);
                    if (apartment != null)
                    {
                        apt.ResidentProfiles.Add(new ResidentProfile
                        {
                            UserId = user.Id,
                            ApartmentId = apartment.Id,
                            NationalId = model.NationalId,
                            Phone = model.PhoneNumber,
                            Email = model.Email,
                            ResidentType = model.ResidentType ?? "Owner",
                            IsVerifiedByBQL = false, // Chờ duyệt
                            DateJoined = DateTime.UtcNow
                        });
                        await apt.SaveChangesAsync();
                        return Content("Đăng ký thành công. Vui lòng chờ Ban quản lý duyệt yêu cầu liên kết căn hộ.", "text/plain; charset=utf-8");
                    }
                }
            }

                // Nếu không có đủ thông tin liên kết căn hộ
                return Content("Đăng ký thành công. Vui lòng đăng nhập và liên kết căn hộ của bạn.", "text/plain; charset=utf-8");
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi đăng ký", _logger);
            }
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest model)
        {
            try
            {
                // Validation
                if (model == null)
                    return BadRequest(new { error = "Dữ liệu không hợp lệ" });
                
                if (string.IsNullOrWhiteSpace(model.Username))
                    return BadRequest(new { error = "Tên đăng nhập là bắt buộc" });
                
                if (string.IsNullOrWhiteSpace(model.Password))
                    return BadRequest(new { error = "Mật khẩu là bắt buộc" });
                
                // Rate limiting: Check if IP is locked out
                var clientIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
                var lockoutKey = $"login_lockout_{clientIp}_{model.Username}";
                
                if (_cache.TryGetValue(lockoutKey, out _))
                {
                    _logger.LogWarning("Login attempt blocked due to rate limiting for IP: {IP}, Username: {Username}", clientIp, model.Username);
                    return StatusCode(429, new { error = $"Quá nhiều lần đăng nhập sai. Vui lòng thử lại sau {LOCKOUT_DURATION_MINUTES} phút." });
                }
                
                // Rate limiting: Check failed attempts
                var attemptsKey = $"login_attempts_{clientIp}_{model.Username}";
                var attempts = _cache.Get<int?>(attemptsKey) ?? 0;
                
                var user = await _userManager.FindByNameAsync(model.Username);
                if (user == null)
                {
                    await RecordFailedAttempt(attemptsKey, attempts);
                    return Unauthorized(new { error = "Sai username hoặc mật khẩu" });
                }

                var passwordOk = await _signInManager.CheckPasswordSignInAsync(user, model.Password, false);
                if (!passwordOk.Succeeded)
                {
                    await RecordFailedAttempt(attemptsKey, attempts);
                    return Unauthorized(new { error = "Sai username hoặc mật khẩu" });
                }

                if (!user.IsApproved)
                    return Unauthorized(new { error = "Tài khoản chưa được duyệt" });

                // Reset failed attempts on successful login
                _cache.Remove(attemptsKey);
                
                var token = await _tokenService.CreateAsync(user);
                var roles = (await _userManager.GetRolesAsync(user)).ToList();
                var landingPath = ResolveLandingPath(roles);

                _logger.LogInformation("Successful login for user: {Username}", model.Username);

                return Ok(new LoginResponse
                {
                    AccessToken = token,
                    Username = user.UserName!,
                    FullName = user.FullName,
                    Roles = roles,
                    IsApproved = user.IsApproved,
                    LandingPath = landingPath
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi đăng nhập", _logger);
            }
        }

        private static string? ResolveLandingPath(IReadOnlyCollection<string> roles)
        {
            // Ưu tiên rõ ràng để FE redirect đúng trang
            if (roles.Contains("Security")) return "/locker";
            if (roles.Contains("Manager")) return "/admin";
            if (roles.Contains("Resident")) return "/app";
            if (roles.Contains("Seller")) return "/seller";
            if (roles.Contains("Vendor")) return "/vendor";
            return null;
        }
        
        private Task RecordFailedAttempt(string attemptsKey, int currentAttempts)
        {
            var newAttempts = currentAttempts + 1;
            
            if (newAttempts >= MAX_LOGIN_ATTEMPTS)
            {
                // Lock out for specified duration
                _cache.Set(attemptsKey, newAttempts, TimeSpan.FromMinutes(LOCKOUT_DURATION_MINUTES));
                var lockoutKey = attemptsKey.Replace("login_attempts_", "login_lockout_");
                _cache.Set(lockoutKey, true, TimeSpan.FromMinutes(LOCKOUT_DURATION_MINUTES));
                _logger.LogWarning("Account locked due to {Attempts} failed login attempts", newAttempts);
            }
            else
            {
                // Increment attempts counter (expires in 15 minutes)
                _cache.Set(attemptsKey, newAttempts, TimeSpan.FromMinutes(LOCKOUT_DURATION_MINUTES));
            }
            
            return Task.CompletedTask;
        }

        /// <summary>
        /// Tạo OTP 6 số an toàn
        /// </summary>
        private static string GenerateOtp6Digits()
        {
            // OTP 6 số, dùng RandomNumberGenerator cho an toàn
            using var rng = RandomNumberGenerator.Create();
            var bytes = new byte[4];
            rng.GetBytes(bytes);
            var value = BitConverter.ToUInt32(bytes, 0) % 1_000_000;
            return value.ToString("D6");
        }

        /// <summary>
        /// Gửi mã OTP quên mật khẩu qua email
        /// </summary>
        [HttpPost("forgot-password-email")]
        [AllowAnonymous]
        public async Task<IActionResult> ForgotPasswordEmail([FromBody] ForgotPasswordEmailRequest request)
        {
            try
            {
                if (request == null || string.IsNullOrWhiteSpace(request.Email))
                    return BadRequest(new { error = "Email là bắt buộc." });

                var email = request.Email.Trim().ToLowerInvariant();

                var user = await _userManager.Users
                    .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);

                if (user == null)
                    return BadRequest(new { error = "Email không tồn tại." });

                // Tạo OTP 6 số
                var otp = GenerateOtp6Digits();

                user.PasswordResetOtp = otp;
                user.PasswordResetOtpExpiryUtc = DateTime.UtcNow.AddMinutes(5);
                user.PasswordResetOtpAttempts = 0;

                await _userManager.UpdateAsync(user);

                var subject = "Mã OTP đặt lại mật khẩu ICitizen";
                var body = $@"
<h2>Mã OTP đặt lại mật khẩu của bạn là: <b>{otp}</b></h2>
<p>OTP có hiệu lực trong 5 phút.</p>
<p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>";

                await _emailSender.SendEmailAsync(user.Email!, subject, body);

                return Ok(new { message = "Đã gửi OTP về email của bạn." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi gửi OTP qua email");
                return StatusCode(500, new { error = "Có lỗi xảy ra khi gửi OTP, vui lòng thử lại sau." });
            }
        }

        /// <summary>
        /// Xác thực OTP & đổi mật khẩu bằng email
        /// </summary>
        [HttpPost("reset-password-email")]
        [AllowAnonymous]
        public async Task<IActionResult> ResetPasswordEmail([FromBody] ResetPasswordEmailRequest request)
        {
            try
            {
                if (request == null ||
                    string.IsNullOrWhiteSpace(request.Email) ||
                    string.IsNullOrWhiteSpace(request.Otp) ||
                    string.IsNullOrWhiteSpace(request.NewPassword))
                {
                    return BadRequest(new { error = "Email, OTP và mật khẩu mới là bắt buộc." });
                }

                var email = request.Email.Trim().ToLowerInvariant();

                var user = await _userManager.Users
                    .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);

                if (user == null)
                    return BadRequest(new { error = "Email không tồn tại." });

                if (string.IsNullOrEmpty(user.PasswordResetOtp) ||
                    user.PasswordResetOtpExpiryUtc == null)
                {
                    return BadRequest(new { error = "Không tìm thấy yêu cầu đặt lại mật khẩu. Vui lòng gửi lại OTP." });
                }

                if (user.PasswordResetOtpExpiryUtc < DateTime.UtcNow)
                {
                    return BadRequest(new { error = "OTP đã hết hạn. Vui lòng yêu cầu OTP mới." });
                }

                if (user.PasswordResetOtpAttempts >= 5)
                {
                    return BadRequest(new { error = "Bạn đã nhập sai OTP quá số lần cho phép. Vui lòng yêu cầu mã OTP mới." });
                }

                if (!string.Equals(user.PasswordResetOtp, request.Otp, StringComparison.Ordinal))
                {
                    user.PasswordResetOtpAttempts++;
                    await _userManager.UpdateAsync(user);
                    return BadRequest(new { error = "OTP không đúng." });
                }

                // Đổi mật khẩu
                var hasPassword = await _userManager.HasPasswordAsync(user);
                IdentityResult result;
                if (hasPassword)
                {
                    await _userManager.RemovePasswordAsync(user);
                }
                result = await _userManager.AddPasswordAsync(user, request.NewPassword);

                if (!result.Succeeded)
                {
                    var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                    return BadRequest(new { error = errors });
                }

                // Xóa OTP sau khi dùng
                user.PasswordResetOtp = null;
                user.PasswordResetOtpExpiryUtc = null;
                user.PasswordResetOtpAttempts = 0;
                await _userManager.UpdateAsync(user);

                return Ok(new { message = "Đặt lại mật khẩu thành công." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi reset mật khẩu qua email");
                return StatusCode(500, new { error = "Có lỗi xảy ra khi đặt lại mật khẩu, vui lòng thử lại sau." });
            }
        }

        [Authorize]
        [HttpGet("profile")]
        public async Task<IActionResult> Profile()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var roles = (await _userManager.GetRolesAsync(user)).ToList();
            // Apartment code nếu có trong ResidentProfile
            var db = HttpContext.RequestServices.GetService(typeof(ICitizen.Data.ApplicationDbContext)) as ICitizen.Data.ApplicationDbContext;
            string? apartmentCode = null;
            bool? residentVerified = null;
            if (db != null)
            {
                var rp = db.ResidentProfiles.Include(r => r.Apartment).FirstOrDefault(r => r.UserId == user.Id);
                apartmentCode = rp?.Apartment?.Code;
                residentVerified = rp?.IsVerifiedByBQL;
            }
            return Ok(new ProfileResponse
            {
                Username = user.UserName!,
                FullName = user.FullName,
                Roles = roles,
                IsApproved = user.IsApproved,
                UserId = user.Id,
                ApartmentCode = apartmentCode,
                IsResidentVerified = residentVerified
            });
        }
    }
}
