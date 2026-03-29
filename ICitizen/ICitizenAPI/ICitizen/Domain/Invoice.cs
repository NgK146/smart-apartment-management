using ICitizen.Models;

namespace ICitizen.Domain;

public class Invoice : BaseEntity
{
    public Guid ApartmentId { get; set; }
    public Apartment? Apartment { get; set; }
    public string? UserId { get; set; } // cư dân nhận hóa đơn (nếu cần)
    public AppUser? User { get; set; }
    public InvoiceType Type { get; set; } = InvoiceType.ManagementFee;
    public int Month { get; set; } // Tháng của hóa đơn (1-12)
    public int Year { get; set; } // Năm của hóa đơn
    public DateTime PeriodStart { get; set; }
    public DateTime PeriodEnd { get; set; }
    public DateTime DueDate { get; set; } // Hạn thanh toán
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Unpaid;
    public decimal TotalAmount { get; set; } = 0m;
    public ICollection<InvoiceLine> Lines { get; set; } = new List<InvoiceLine>();
}
