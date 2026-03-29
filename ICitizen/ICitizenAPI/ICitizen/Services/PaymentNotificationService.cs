using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ICitizen.Services;

public class PaymentNotificationService : IPaymentNotificationService
{
    private readonly ApplicationDbContext _db;
    private readonly IHubContext<PaymentHub> _hub;
    private readonly ILogger<PaymentNotificationService> _logger;

    public PaymentNotificationService(
        ApplicationDbContext db,
        IHubContext<PaymentHub> hub,
        ILogger<PaymentNotificationService> logger)
    {
        _db = db;
        _hub = hub;
        _logger = logger;
    }

    public async Task NotifyPaymentUpdatedAsync(Payment payment, CancellationToken cancellationToken = default)
    {
        await _db.Entry(payment).Reference(p => p.Invoice).LoadAsync(cancellationToken);
        if (payment.Invoice != null)
        {
            await _db.Entry(payment.Invoice).Reference(i => i.Apartment).LoadAsync(cancellationToken);
        }

        var payload = new
        {
            paymentId = payment.Id,
            invoiceId = payment.InvoiceId,
            status = payment.Status.ToString(),
            amount = payment.Amount,
            paidAtUtc = payment.PaidAtUtc,
            invoiceStatus = payment.Invoice?.Status.ToString(),
            apartmentCode = payment.Invoice?.Apartment?.Code,
            month = payment.Invoice?.Month,
            year = payment.Invoice?.Year,
            method = payment.Method.ToString()
        };

        if (!string.IsNullOrEmpty(payment.Invoice?.UserId))
        {
            await _hub.Clients.Group($"user:{payment.Invoice.UserId}")
                .SendAsync("paymentUpdated", payload, cancellationToken: cancellationToken);
        }

        await _hub.Clients.Group("managers")
            .SendAsync("paymentUpdated", payload, cancellationToken: cancellationToken);

        _logger.LogInformation("Broadcast payment update for invoice {InvoiceId}, payment {PaymentId}", payment.InvoiceId, payment.Id);
    }

    public async Task NotifyInvoiceCreatedAsync(Invoice invoice, CancellationToken cancellationToken = default)
    {
        // Load relationships
        await _db.Entry(invoice).Reference(i => i.Apartment).LoadAsync(cancellationToken);
        await _db.Entry(invoice).Collection(i => i.Lines).LoadAsync(cancellationToken);

        var payload = new
        {
            invoiceId = invoice.Id,
            apartmentId = invoice.ApartmentId,
            apartmentCode = invoice.Apartment?.Code,
            totalAmount = invoice.TotalAmount,
            month = invoice.Month,
            year = invoice.Year,
            dueDate = invoice.DueDate,
            status = invoice.Status.ToString(),
            type = invoice.Type.ToString()
        };

        // Notify resident of the apartment
        if (!string.IsNullOrEmpty(invoice.UserId))
        {
            await _hub.Clients.Group($"user:{invoice.UserId}")
                .SendAsync("invoiceCreated", payload, cancellationToken: cancellationToken);
            
            _logger.LogInformation("Notified user {UserId} about new invoice {InvoiceId}", invoice.UserId, invoice.Id);
        }
        else if (invoice.ApartmentId != Guid.Empty)
        {
            // Find residents of this apartment
            var residents = await _db.ResidentProfiles
                .Where(r => r.ApartmentId == invoice.ApartmentId && !string.IsNullOrEmpty(r.UserId))
                .ToListAsync(cancellationToken);

            foreach (var resident in residents)
            {
                await _hub.Clients.Group($"user:{resident.UserId}")
                    .SendAsync("invoiceCreated", payload, cancellationToken: cancellationToken);
                
                _logger.LogInformation("Notified resident {UserId} about new invoice {InvoiceId}", resident.UserId, invoice.Id);
            }
        }

        // Notify managers
        await _hub.Clients.Group("managers")
            .SendAsync("invoiceCreated", payload, cancellationToken: cancellationToken);

        _logger.LogInformation("Broadcast invoice created notification for {InvoiceId} - Apartment {ApartmentCode}, Amount {Amount}", 
            invoice.Id, invoice.Apartment?.Code, invoice.TotalAmount);
    }
}


