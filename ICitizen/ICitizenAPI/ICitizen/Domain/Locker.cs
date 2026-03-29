using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Locker : BaseEntity
{
    [MaxLength(50)] public string Code { get; set; } = string.Empty; // e.g., "L1"
    [MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(200)] public string Location { get; set; } = string.Empty;
    public ICollection<Compartment> Compartments { get; set; } = new List<Compartment>();
}
