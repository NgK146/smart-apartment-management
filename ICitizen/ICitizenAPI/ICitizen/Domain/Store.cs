using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ICitizen.Models;

namespace ICitizen.Domain;

public class Store : BaseEntity
{
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Description { get; set; }

    [MaxLength(20)]
    public string? Phone { get; set; }

    [MaxLength(500)]
    public string? LogoUrl { get; set; }

    [MaxLength(500)]
    public string? CoverImageUrl { get; set; }

    public bool IsApproved { get; set; } = false; // BQL phải duyệt
    public bool IsActive { get; set; } = true; // BQL có thể tạm khóa

    // Khóa ngoại - Liên kết với tài khoản người dùng (chủ sở hữu)
    [Required]
    [MaxLength(450)] // Chiều dài ID của Identity
    public string OwnerId { get; set; } = string.Empty;

    [ForeignKey(nameof(OwnerId))]
    public virtual AppUser? Owner { get; set; }

    // Quan hệ
    public virtual ICollection<ProductCategory> ProductCategories { get; set; } = new List<ProductCategory>();
    public virtual ICollection<Product> Products { get; set; } = new List<Product>();
    public virtual ICollection<StoreReview> Reviews { get; set; } = new List<StoreReview>();
    public virtual ICollection<Order> Orders { get; set; } = new List<Order>();
}

