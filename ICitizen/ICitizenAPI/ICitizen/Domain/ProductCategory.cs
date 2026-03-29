using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ICitizen.Domain;

public class ProductCategory : BaseEntity
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    // Khóa ngoại - Danh mục này thuộc Cửa hàng nào
    [Required]
    public Guid StoreId { get; set; }

    [ForeignKey(nameof(StoreId))]
    public virtual Store? Store { get; set; }

    // Quan hệ
    public virtual ICollection<Product> Products { get; set; } = new List<Product>();
}

