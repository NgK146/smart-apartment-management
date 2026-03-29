using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Compartment : BaseEntity
{
    [MaxLength(50)] public string Code { get; set; } = string.Empty; // e.g., "L1-C12"
    
    public Guid LockerId { get; set; }
    public Locker? Locker { get; set; }
    
    public Guid ApartmentId { get; set; }  // NOT NULL - Each compartment is always assigned to exactly 1 apartment
    public Apartment? Apartment { get; set; }
    
    public CompartmentStatus Status { get; set; } = CompartmentStatus.Empty;
}
