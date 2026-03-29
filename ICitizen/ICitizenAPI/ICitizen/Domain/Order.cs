using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ICitizen.Models;

namespace ICitizen.Domain;

public class Order : BaseEntity
{
    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal TotalAmount { get; set; }

    public OrderStatus Status { get; set; } = OrderStatus.Pending;

    [MaxLength(500)]
    public string? Notes { get; set; } // Ghi chú của người mua

    // Khóa ngoại
    [Required]
    [MaxLength(450)]
    public string BuyerId { get; set; } = string.Empty; // Cư dân mua

    [ForeignKey(nameof(BuyerId))]
    public virtual AppUser? Buyer { get; set; }

    [Required]
    public Guid StoreId { get; set; } // Cửa hàng bán

    [ForeignKey(nameof(StoreId))]
    public virtual Store? Store { get; set; }

    // Quan hệ
    public virtual ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
    public virtual ICollection<StoreReview> Reviews { get; set; } = new List<StoreReview>();
}

