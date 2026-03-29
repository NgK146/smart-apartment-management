using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Vehicle : BaseEntity
{
    [MaxLength(50)] public string LicensePlate { get; set; } = string.Empty; 
    [MaxLength(100)] public string VehicleType { get; set; } = string.Empty; 
    [MaxLength(100)] public string? Brand { get; set; } 
    [MaxLength(100)] public string? Model { get; set; } 
    [MaxLength(50)] public string? Color { get; set; } 
    public Guid ResidentProfileId { get; set; } 
    public ResidentProfile? ResidentProfile { get; set; }
    public bool IsActive { get; set; } = true; 
    [MaxLength(50)] public string Status { get; set; } = "Pending"; 
    [MaxLength(500)] public string? RejectionReason { get; set; } 
}


