using System.Collections.Generic;

namespace ICitizen.Models
{
    public class RegisterRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string PhoneNumber { get; set; } = string.Empty;

        // mở rộng cho Flutter
        public string? DesiredRole { get; set; }   // "Resident" | "Vendor"
        public string? InviteCode { get; set; }   // nếu Vendor
        
        // Giai đoạn 2: Liên kết căn hộ (chỉ cho Resident)
        public string? ApartmentCode { get; set; } // Mã căn hộ
        public string? NationalId { get; set; }   // CMND/CCCD
        public string? ResidentType { get; set; } // "Owner" | "Tenant"
    }

    public class LoginRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class LoginResponse
    {
        public string AccessToken { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string? FullName { get; set; }
        public List<string> Roles { get; set; } = new();
        public bool IsApproved { get; set; }
        // Đường dẫn FE có thể dùng để redirect sau login (tùy role)
        public string? LandingPath { get; set; }
    }

    public class ProfileResponse
    {
        public string Username { get; set; } = string.Empty;
        public string? FullName { get; set; }
        public List<string> Roles { get; set; } = new();
        public bool IsApproved { get; set; }
        public string? UserId { get; set; }
        public string? ApartmentCode { get; set; }
        public bool? IsResidentVerified { get; set; }
    }

    public class ForgotPasswordEmailRequest
    {
        public string Email { get; set; } = string.Empty;
    }

    public class ResetPasswordEmailRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Otp { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
