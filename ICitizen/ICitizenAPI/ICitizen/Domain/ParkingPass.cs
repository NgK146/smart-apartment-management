using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

/// <summary>
/// Vé xe đã đăng ký của cư dân, liên kết Vehicle và ParkingPlan
/// </summary>
public class ParkingPass : BaseEntity
{
    [Required]
    public Guid VehicleId { get; set; } // Xe nào
    public Vehicle? Vehicle { get; set; }

    [Required]
    public Guid ParkingPlanId { get; set; } // Gói vé nào
    public ParkingPlan? ParkingPlan { get; set; }

    [Required]
    [MaxLength(50)]
    public string PassCode { get; set; } = string.Empty; // Mã vé (dùng để tạo QR Code)

    [Required]
    public DateTime ValidFrom { get; set; } // Ngày bắt đầu có hiệu lực

    [Required]
    public DateTime ValidTo { get; set; } // Ngày hết hạn

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "PendingPayment"; // Trạng thái: PendingPayment, Active, Expired, Revoked

    public Guid? InvoiceId { get; set; } // Hóa đơn thanh toán (nếu có)
    public Invoice? Invoice { get; set; }

    public DateTime? ActivatedAt { get; set; } // Thời điểm kích hoạt (khi thanh toán xong)

    [MaxLength(500)]
    public string? RevocationReason { get; set; } // Lý do hủy vé (nếu bị Admin hủy)
}

