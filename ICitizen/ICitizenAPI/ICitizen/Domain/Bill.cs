using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Bill : BaseEntity
{
    public Guid ResidentProfileId { get; set; }

    [MaxLength(50)]
    public string Type { get; set; } = string.Empty; // "Service", "Electric", "Water", "Parking"

    public DateTime DueDate { get; set; }
    public bool IsPaid { get; set; }

    public ResidentProfile? ResidentProfile { get; set; }
}

