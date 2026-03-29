using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Amenity : BaseEntity
{
    [MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(400)] public string? Description { get; set; }
    public bool AllowBooking { get; set; } = true;
    public decimal? PricePerHour { get; set; }

    // ===== Extended fields =====
    [MaxLength(50)] public string? Category { get; set; }           // Thể thao / Giải trí / Dịch vụ…
    [MaxLength(300)] public string? ImageUrl { get; set; }          // Ảnh đại diện
    [MaxLength(100)] public string? Location { get; set; }          // Ví dụ: Tầng M - Khu A

    // Giờ hoạt động mặc định (0-23). Null = không giới hạn
    public int? OpenHourStart { get; set; }                         // ví dụ 6
    public int? OpenHourEnd { get; set; }                           // ví dụ 22

    // Quy tắc sử dụng
    [MaxLength(1000)] public string? UsageRules { get; set; }

    // Thiết lập đặt lịch
    public int? MinDurationMinutes { get; set; }                    // ví dụ 30
    public int? MaxDurationMinutes { get; set; }                    // ví dụ 90
    public int? MaxAdvanceDays { get; set; }                        // ví dụ 7
    public bool RequireManualApproval { get; set; } = false;        // nếu true thì luôn Pending
    public int? MaxPerDay { get; set; }                             // giới hạn/cư dân/ngày
    public int? MaxPerWeek { get; set; }                            // giới hạn/cư dân/tuần

    // Chi phí
    public bool RequirePrepayment { get; set; } = false;            // yêu cầu thanh toán trước
}
