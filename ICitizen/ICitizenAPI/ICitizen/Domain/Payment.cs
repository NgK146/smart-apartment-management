using System.ComponentModel.DataAnnotations;

namespace ICitizen.Domain;

public class Payment : BaseEntity
{
    public Guid InvoiceId { get; set; }
    public Invoice? Invoice { get; set; }
    public decimal Amount { get; set; }
    public PaymentMethod Method { get; set; } = PaymentMethod.Cash; // Momo/ZaloPay/ViettelPay/VNPay...
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
    public DateTime? PaidAtUtc { get; set; }
    [MaxLength(200)] public string? TransactionRef { get; set; } // Mã giao dịch từ cổng thanh toán hoặc ngân hàng
    [MaxLength(50)] public string? TransactionCode { get; set; } // Mã giao dịch từ cổng thanh toán (VNPAY vnp_TxnRef)
    [MaxLength(10)] public string? ErrorCode { get; set; } // Mã lỗi từ cổng thanh toán (VD: vnp_ResponseCode)
    [MaxLength(500)] public string? ErrorMessage { get; set; } // Mô tả lỗi thân thiện
    [MaxLength(66)] public string? BlockchainTxHash { get; set; } // Hash giao dịch blockchain (proof minh bạch)
}
