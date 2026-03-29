namespace ICitizen.Domain;

public class ConciergeRequest : BaseEntity
{

    /// <summary>
    /// Mã dịch vụ (từ mobile gửi lên, ví dụ: "1" = Dọn phòng).
    /// Sau này có thể map sang bảng dịch vụ riêng.
    /// </summary>
    public string ServiceId { get; set; } = default!;

    public string ServiceName { get; set; } = string.Empty;

    /// <summary>
    /// User Id trong AspNetUsers
    /// </summary>
    public string UserId { get; set; } = default!;

    /// <summary>
    /// Ghi chú / mô tả yêu cầu từ cư dân
    /// </summary>
    public string? Notes { get; set; }

    /// <summary>
    /// Thời gian mong muốn thực hiện (nếu có)
    /// </summary>
    public DateTime? ScheduledForUtc { get; set; }

    /// <summary>
    /// Trạng thái xử lý
    /// </summary>
    public ConciergeRequestStatus Status { get; set; } = ConciergeRequestStatus.Pending;
}


