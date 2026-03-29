using ICitizen.Domain;

namespace ICitizen.Controllers;

public class SupportTicketSummaryDto
{
    public Guid TicketId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public string? ApartmentCode { get; set; }
    public SupportTicketStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public string? LastMessagePreview { get; set; }
    public DateTime? LastMessageAtUtc { get; set; }
    public string? AssignedToId { get; set; }
    public string? AssignedToName { get; set; }
}

public class SupportTicketDetailDto
{
    public Guid TicketId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string CreatedById { get; set; } = string.Empty;
    public string CreatedByName { get; set; } = string.Empty;
    public string? ApartmentCode { get; set; }
    public string? Category { get; set; }
    public SupportTicketStatus Status { get; set; }
    public string? AssignedToId { get; set; }
    public string? AssignedToName { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
    public List<SupportTicketMessageDto> Messages { get; set; } = new();
}

public class SupportTicketMessageDto
{
    public Guid Id { get; set; }
    public Guid TicketId { get; set; }
    public string SenderId { get; set; } = string.Empty;
    public string SenderName { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsFromStaff { get; set; }
}
