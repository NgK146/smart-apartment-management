namespace ICitizen.Domain;

public class AmenityBooking : BaseEntity
{
    public Guid AmenityId { get; set; }
    public Amenity? Amenity { get; set; }
    public string UserId { get; set; } = string.Empty; // cư dân đặt
    public DateTime StartTimeUtc { get; set; }
    public DateTime EndTimeUtc { get; set; }
    public AmenityBookingStatus Status { get; set; } = AmenityBookingStatus.Pending;
    public decimal? Price { get; set; }

    // Extra booking details
    public string? ContactPhone { get; set; }
    public string? Purpose { get; set; }
    public int? ParticipantCount { get; set; }
    public PaymentStatus? PaymentStatus { get; set; } // Pending/Confirmed
    public string? TransactionRef { get; set; }
    public int ReminderOffsetMinutes { get; set; } = 60; // phút trước giờ bắt đầu
    public DateTime? ReminderSentAtUtc { get; set; }
}
