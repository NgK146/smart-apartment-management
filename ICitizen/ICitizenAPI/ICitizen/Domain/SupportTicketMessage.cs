using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class SupportTicketMessage : BaseEntity
{
    public Guid TicketId { get; set; }

    [MaxLength(450)]
    public string SenderId { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    [MaxLength(1024)]
    public string? AttachmentUrl { get; set; }

    public bool IsFromStaff { get; set; }

    public SupportTicket Ticket { get; set; } = default!;
}

