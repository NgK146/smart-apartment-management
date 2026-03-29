using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class UserNotification : BaseEntity
{
    [MaxLength(450)] public string UserId { get; set; } = string.Empty;
    [MaxLength(200)] public string Title { get; set; } = string.Empty;
    [MaxLength(2000)] public string Message { get; set; } = string.Empty;
    [MaxLength(50)] public string Type { get; set; } = "General";
    [MaxLength(50)] public string? RefType { get; set; }
    public Guid? RefId { get; set; }
    public DateTime? ReadAtUtc { get; set; }

    public bool IsRead => ReadAtUtc != null;
}


