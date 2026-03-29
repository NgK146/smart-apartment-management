using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class InternalTask : BaseEntity
{
    [MaxLength(200)] public string Title { get; set; } = string.Empty;
    [MaxLength(2000)] public string? Description { get; set; }
    public InternalTaskType Type { get; set; } = InternalTaskType.Maintenance; // Bảo dưỡng, Sửa chữa, Vận hành,...
    public InternalTaskPriority Priority { get; set; } = InternalTaskPriority.Normal;
    public InternalTaskStatus Status { get; set; } = InternalTaskStatus.Pending;
    public Guid? ApartmentId { get; set; } // Liên quan đến căn hộ nào (nếu có)
    public Apartment? Apartment { get; set; }
    public string? AssignedToUserId { get; set; } // Người được giao
    public string? CreatedByUserId { get; set; } // Người tạo
    public DateTime? DueDate { get; set; } // Hạn hoàn thành
    public DateTime? CompletedAtUtc { get; set; } // Ngày hoàn thành
    [MaxLength(1000)] public string? Notes { get; set; } // Ghi chú
}

public enum InternalTaskType { Maintenance, Repair, Operation, Cleaning, Security, Other }
public enum InternalTaskPriority { Low, Normal, High, Urgent }
public enum InternalTaskStatus { Pending, InProgress, Completed, Cancelled }


