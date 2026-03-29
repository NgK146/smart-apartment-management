using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class LockerTransaction : BaseEntity
{
    public Guid ApartmentId { get; set; }
    public Apartment? Apartment { get; set; }
    
    public Guid CompartmentId { get; set; }
    public Compartment? Compartment { get; set; }
    
    [MaxLength(450)] public string SecurityUserId { get; set; } = string.Empty; // Who received from shipper
    
    public LockerTransactionStatus Status { get; set; } = LockerTransactionStatus.ReceivedBySecurity;
    
    public DateTime? DropTime { get; set; }       // When security stored in locker
    public DateTime? PickupTime { get; set; }     // When resident picked up
    
    [MaxLength(256)] public string? DropTokenHash { get; set; }      // For security to open (optional, for demo)
    [MaxLength(256)] public string? PickupTokenHash { get; set; }    // For resident (OTP hash)
    
    public DateTime? PickupTokenExpireAt { get; set; }
    
    [MaxLength(500)] public string? Notes { get; set; }
}
