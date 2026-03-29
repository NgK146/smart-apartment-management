namespace ICitizen.Domain;

public class CommunityMessage : BaseEntity
{
    public string Room { get; set; } = "general";
    public string SenderId { get; set; } = string.Empty;
    public string SenderName { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? AttachmentType { get; set; }
    public string? AttachmentUrl { get; set; }
    public double? AttachmentDurationSeconds { get; set; }
}

