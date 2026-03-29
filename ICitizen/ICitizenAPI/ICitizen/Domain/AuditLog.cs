using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class AuditLog : BaseEntity
{
    public Guid TransactionId { get; set; }
    public LockerTransaction? Transaction { get; set; }
    
    [MaxLength(100)] public string Action { get; set; } = string.Empty; // OPEN_DROP, CONFIRM_STORED, VERIFY_PICKUP, etc.
    
    [MaxLength(450)] public string ByUserId { get; set; } = string.Empty;
    
    public DateTime At { get; set; } = DateTime.UtcNow;
    
    [MaxLength(500)] public string? Note { get; set; }
}
