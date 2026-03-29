using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ICitizen.Domain;

public class Product : BaseEntity
{
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Description { get; set; }

    [Required]
    [Column(TypeName = "decimal(18,2)")]
    public decimal Price { get; set; }

    [MaxLength(500)]
    public string? ImageUrl { get; set; }

    public ProductType Type { get; set; } = ProductType.Physical;
    public bool IsAvailable { get; set; } = true; // Còn hàng/Còn nhận dịch vụ không

    // Khóa ngoại
    [Required]
    public Guid StoreId { get; set; }

    [ForeignKey(nameof(StoreId))]
    public virtual Store? Store { get; set; }

    [Required]
    public Guid ProductCategoryId { get; set; }

    [ForeignKey(nameof(ProductCategoryId))]
    public virtual ProductCategory? ProductCategory { get; set; }

    // Quan hệ
    public virtual ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
}

