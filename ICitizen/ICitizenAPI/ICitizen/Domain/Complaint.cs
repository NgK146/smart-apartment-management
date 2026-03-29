using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Complaint : BaseEntity
{
    [MaxLength(200)] public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public ComplaintCategory Category { get; set; } = ComplaintCategory.Other;
    public ComplaintStatus Status { get; set; } = ComplaintStatus.Pending;
    public string CreatedByUserId { get; set; } = string.Empty;
    public string? AssignedToUserId { get; set; }
    public DateTime? ResolvedAtUtc { get; set; }
    // Lưu chuỗi URL ảnh/video (phân cách ; ), có thể thay bằng bảng Attachments sau
    public string? MediaUrls { get; set; }
    
    // Thêm các trường cho module Phản ánh
    [MaxLength(100)]
    public string? EmailNguoiGui { get; set; }
    
    [MaxLength(100)]
    public string? TenNguoiGui { get; set; }
    
    public string? PhanHoiAdmin { get; set; } // Phản hồi từ admin
    
    public ICollection<ComplaintComment> Comments { get; set; } = new List<ComplaintComment>();
} // :contentReference[oaicite:9]{index=9}
