using ICitizen.Domain;

namespace ICitizen.Services;

public interface IPaymentNotificationService
{
    Task NotifyPaymentUpdatedAsync(Payment payment, CancellationToken cancellationToken = default);
    Task NotifyInvoiceCreatedAsync(Invoice invoice, CancellationToken cancellationToken = default);
}


