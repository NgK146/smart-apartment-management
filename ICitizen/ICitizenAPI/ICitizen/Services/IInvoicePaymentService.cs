using ICitizen.Domain;
using Microsoft.AspNetCore.Http;

namespace ICitizen.Services;

public record InvoicePaymentResult(Payment Payment, string QrData);

public interface IInvoicePaymentService
{
    Task<InvoicePaymentResult> EnsureVnPayPaymentAsync(
        Invoice invoice,
        HttpContext httpContext,
        string? orderInfo = null,
        bool forceNew = false,
        CancellationToken cancellationToken = default);
}


