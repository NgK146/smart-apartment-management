using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class ResidentProfile : BaseEntity
{
    [MaxLength(50)] public string? NationalId { get; set; }
    [MaxLength(20)] public string? Phone { get; set; }
    [MaxLength(100)] public string? Email { get; set; }
    public Guid ApartmentId { get; set; }
    public Apartment? Apartment { get; set; }
    public string UserId { get; set; } = string.Empty;  // AppUser Id

    // Extended fields
    public bool IsVerifiedByBQL { get; set; } = false;  // đã được BQL xác minh là cư dân
    public DateTime? DateJoined { get; set; }           // ngày trở thành cư dân
    public int? NumResidents { get; set; }              // số người trong hộ
    [MaxLength(20)] public string? ResidentType { get; set; } // Owner/Tenant

    // For activity suggestions
    public int? Age { get; set; }
    [MaxLength(50)] public string? LifeStyle { get; set; } // "gia_dinh", "doc_than", "nguoi_gia", etc.
    [MaxLength(1000)] public string? PreferredActivitiesJson { get; set; }
    [MaxLength(10)] public string? Building { get; set; } // "A", "B", ...
    public int? Floor { get; set; } // 1, 2, 3...
}
