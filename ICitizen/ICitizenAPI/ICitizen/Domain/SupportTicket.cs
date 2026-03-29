using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class SupportTicket : BaseEntity
{
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(450)]
    public string CreatedById { get; set; } = string.Empty;

    [MaxLength(450)]
    public string? AssignedToId { get; set; }

    [MaxLength(50)]
    public string? ApartmentCode { get; set; }

    [MaxLength(50)]
    public string? Category { get; set; }

    public SupportTicketStatus Status { get; set; } = SupportTicketStatus.New;

    public ICollection<SupportTicketMessage> Messages { get; set; } = new List<SupportTicketMessage>();
}

