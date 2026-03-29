using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Apartment : BaseEntity
{
    [MaxLength(20)] public string Code { get; set; } = string.Empty; // duy nhất
    [MaxLength(100)] public string Building { get; set; } = string.Empty;
    public int Floor { get; set; }
    public decimal? AreaM2 { get; set; }
    public ApartmentStatus Status { get; set; } = ApartmentStatus.Available; // Trạng thái căn hộ
    public ICollection<ResidentProfile> Residents { get; set; } = new List<ResidentProfile>();
    
    // Locker management - 1-to-1 relationship
    public Compartment? Compartment { get; set; }
}
