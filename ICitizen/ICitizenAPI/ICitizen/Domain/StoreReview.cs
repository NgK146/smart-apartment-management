using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ICitizen.Models;

namespace ICitizen.Domain;

public class StoreReview : BaseEntity
{
    [Required]
    [Range(1, 5)]
    public int Rating { get; set; } // 1-5 sao

    [MaxLength(1000)]
    public string? Comment { get; set; }

    // Khóa ngoại
    [Required]
    public Guid StoreId { get; set; }

    [ForeignKey(nameof(StoreId))]
    public virtual Store? Store { get; set; }

    [Required]
    [MaxLength(450)]
    public string ResidentId { get; set; } = string.Empty; // Người đánh giá

    [ForeignKey(nameof(ResidentId))]
    public virtual AppUser? Resident { get; set; }

    // Tùy chọn: Liên kết với 1 đơn hàng cụ thể
    public Guid? OrderId { get; set; }

    [ForeignKey(nameof(OrderId))]
    public virtual Order? Order { get; set; }
}

