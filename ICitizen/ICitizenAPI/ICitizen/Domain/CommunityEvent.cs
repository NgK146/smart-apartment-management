using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class CommunityEvent : BaseEntity
{
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }

    [MaxLength(10)]
    public string Building { get; set; } = string.Empty; // "A", "B", ...

    public int? Floor { get; set; } // null = sảnh chung, hoặc tầng cụ thể

    [MaxLength(500)]
    public string Tags { get; set; } = string.Empty; // "su_kien,tre_em,hoat_dong_gia_dinh"
}

