using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Notification : BaseEntity
{
    [MaxLength(200)] public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public NotificationType Type { get; set; } = NotificationType.General;
    public DateTime? EffectiveFrom { get; set; }
    public DateTime? EffectiveTo { get; set; }
    public string CreatedByUserId { get; set; } = string.Empty;
} // :contentReference[oaicite:8]{index=8}
