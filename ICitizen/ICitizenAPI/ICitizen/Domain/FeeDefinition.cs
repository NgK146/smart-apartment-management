using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class FeeDefinition : BaseEntity
{
    [MaxLength(100)] public string Name { get; set; } = string.Empty;
    [MaxLength(400)] public string? Description { get; set; }
    public decimal Amount { get; set; } // đơn giá mặc định (ví dụ: 15000 nếu là PerM2, 100000 nếu là PerUnit)
    public FeeCalculationMethod CalculationMethod { get; set; } = FeeCalculationMethod.Fixed;
    public PeriodType PeriodType { get; set; } = PeriodType.Monthly;
    public bool IsActive { get; set; } = true;
}
