using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class RentalContract : BaseEntity
{
    [MaxLength(50)] public string ContractNumber { get; set; } = string.Empty; // Số hợp đồng
    public Guid ApartmentId { get; set; }
    public Apartment? Apartment { get; set; }
    public Guid ResidentProfileId { get; set; } // Người thuê
    public ResidentProfile? ResidentProfile { get; set; }
    public DateTime StartDate { get; set; } // Ngày bắt đầu
    public DateTime EndDate { get; set; } // Ngày kết thúc
    public decimal MonthlyRent { get; set; } // Tiền thuê hàng tháng
    public decimal Deposit { get; set; } // Tiền đặt cọc
    [MaxLength(1000)] public string? Terms { get; set; } // Điều khoản
    public RentalContractStatus Status { get; set; } = RentalContractStatus.Active; // Active, Expired, Terminated
    public DateTime? SignedAtUtc { get; set; } // Ngày ký
    public string? SignedByUserId { get; set; } // Người ký
    public string? DocumentUrl { get; set; } // URL file hợp đồng PDF
}

public enum RentalContractStatus { Draft, Active, Expired, Terminated }


