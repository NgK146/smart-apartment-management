using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class ServiceProvider : BaseEntity
{
    [MaxLength(200)] public string Name { get; set; } = string.Empty; // Tên đơn vị
    [MaxLength(100)] public string Category { get; set; } = string.Empty; // Danh mục: Taxi, Giúp việc, Cho thuê căn hộ,...
    [MaxLength(20)] public string? Phone { get; set; }
    [MaxLength(100)] public string? Email { get; set; }
    [MaxLength(500)] public string? Address { get; set; }
    [MaxLength(1000)] public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
}


