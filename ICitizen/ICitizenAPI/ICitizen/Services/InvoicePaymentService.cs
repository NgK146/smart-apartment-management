using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ICitizen.Services;

public class InvoicePaymentService : IInvoicePaymentService
{
    private readonly ApplicationDbContext _db;
    private readonly IVnPayService _vnPay;
    private readonly ILogger<InvoicePaymentService> _logger;

    public InvoicePaymentService(
        ApplicationDbContext db,
        IVnPayService vnPay,
        ILogger<InvoicePaymentService> logger)
    {
        _db = db;
        _vnPay = vnPay;
        _logger = logger;
    }

    public async Task<InvoicePaymentResult> EnsureVnPayPaymentAsync(
        Invoice invoice,
        HttpContext httpContext,
        string? orderInfo = null,
        bool forceNew = false,
        CancellationToken cancellationToken = default)
    {
        if (invoice.TotalAmount <= 0)
        {
            throw new InvalidOperationException("Invoice does not require payment.");
        }

        await _db.Entry(invoice).Reference(i => i.Apartment).LoadAsync(cancellationToken);

        Payment? payment = null;

        if (!forceNew)
        {
            payment = await _db.Payments
                .Where(p => p.InvoiceId == invoice.Id && p.Method == PaymentMethod.VNPay && p.Status == PaymentStatus.Pending)
                .OrderByDescending(p => p.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);
        }

        if (payment is null)
        {
            payment = new Payment
            {
                InvoiceId = invoice.Id,
                Amount = invoice.TotalAmount,
                Method = PaymentMethod.VNPay,
                Status = PaymentStatus.Pending,
                TransactionCode = Guid.NewGuid().ToString("N")
            };
            _db.Payments.Add(payment);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var description = orderInfo;
        if (string.IsNullOrWhiteSpace(description))
        {
            var apartmentCode = invoice.Apartment?.Code ?? "căn hộ";
            description = $"Thanh toán hóa đơn {invoice.Month}/{invoice.Year} cho {apartmentCode}";
        }

        var paymentUrl = _vnPay.CreatePaymentUrl(payment.Id, payment.Amount, description, httpContext);
        payment.TransactionCode = payment.Id.ToString("N");

        await _db.SaveChangesAsync(cancellationToken);
        _logger.LogInformation("Generated VNPay QR for invoice {InvoiceId}, payment {PaymentId}", invoice.Id, payment.Id);

        return new InvoicePaymentResult(payment, paymentUrl);
    }
}


