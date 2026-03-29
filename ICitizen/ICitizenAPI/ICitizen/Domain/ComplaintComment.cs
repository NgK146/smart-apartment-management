namespace ICitizen.Domain;

public class ComplaintComment : BaseEntity
{
    public Guid ComplaintId { get; set; }
    public Complaint? Complaint { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
}
