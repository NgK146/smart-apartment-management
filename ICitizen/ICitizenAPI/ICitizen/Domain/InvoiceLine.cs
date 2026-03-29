using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class InvoiceLine : BaseEntity
{
    public Guid InvoiceId { get; set; }
    public Invoice? Invoice { get; set; }

    public Guid? FeeDefinitionId { get; set; }
    public FeeDefinition? FeeDefinition { get; set; }

    [MaxLength(200)] public string FeeName { get; set; } = string.Empty; // Tên khoản phí (copy từ FeeDefinition.Name)
    [MaxLength(500)] public string Description { get; set; } = string.Empty; // Mô tả (ví dụ: "100m² x 15.000đ" hoặc "2 xe máy x 100.000đ")
    public decimal Quantity { get; set; } = 1m;
    public decimal UnitPrice { get; set; } = 0m;
    public decimal Amount { get; set; } = 0m; // Số tiền của khoản phí này
}
