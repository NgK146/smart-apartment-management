using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

/// <summary>
/// Gói vé xe do Admin định nghĩa (ví dụ: "Vé xe máy tháng", 100.000đ, 30 ngày)
/// </summary>
public class ParkingPlan : BaseEntity
{
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty; // Tên gói: "Vé tháng xe máy", "Vé quý ô tô"...

    [MaxLength(500)]
    public string? Description { get; set; } // Mô tả gói vé

    [Required]
    [MaxLength(50)]
    public string VehicleType { get; set; } = string.Empty; // Loại xe: "Xe máy", "Ô tô", "Xe đạp"

    [Required]
    public decimal Price { get; set; } // Giá gói vé

    [Required]
    public int DurationInDays { get; set; } // Thời hạn gói (số ngày)

    public bool IsActive { get; set; } = true; // Gói còn cung cấp không

    // Quan hệ: Một gói có nhiều vé đã bán
    public ICollection<ParkingPass> ParkingPasses { get; set; } = new List<ParkingPass>();
}

