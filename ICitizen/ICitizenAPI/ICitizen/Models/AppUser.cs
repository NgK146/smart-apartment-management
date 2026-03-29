using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations.Schema;

namespace ICitizen.Models;

public class AppUser : IdentityUser
{
    public string? FullName { get; set; }
    public bool IsApproved { get; set; } = false;
    public string? RequestedRole { get; set; }     // Lưu role người dùng mong muốn khi đăng ký (Resident/Vendor)
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    // ===== Chat module fields =====
    // Vai trò đơn giản cho module chat: Admin/User (độc lập với hệ thống role hiện tại)
    [NotMapped]
    public string? UserRole { get; set; } // "Admin" | "User" (không map DB, suy luận từ Roles)
    [NotMapped]
    public string? DisplayName { get; set; } // (không map DB, dùng FullName/UserName)

    // ===== Password Reset OTP fields =====
    public string? PasswordResetOtp { get; set; }
    public DateTime? PasswordResetOtpExpiryUtc { get; set; }
    public int PasswordResetOtpAttempts { get; set; } = 0;
}
