using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PayOS;
using PayOS.Models.Webhooks;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/payos")]
public class PayOSWebhookController : ControllerBase
{
    private readonly PayOSClient _payOsClient;
    private readonly ApplicationDbContext _db;
    private readonly ILogger<PayOSWebhookController> _logger;
    private readonly IPaymentNotificationService _paymentNotificationService;

    public PayOSWebhookController(
        PayOSClient payOsClient,
        ApplicationDbContext db,
        ILogger<PayOSWebhookController> logger,
        IPaymentNotificationService paymentNotificationService)
    {
        _payOsClient = payOsClient;
        _db = db;
        _logger = logger;
        _paymentNotificationService = paymentNotificationService;
    }

    [HttpPost("webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> Webhook([FromBody] Webhook webhook)
    {
        try
        {
            var data = await _payOsClient.Webhooks.VerifyAsync(webhook);
            var orderCode = data?.OrderCode;
            if (orderCode == null)
            {
                _logger.LogWarning("PayOS webhook missing order code");
                return Ok(new { message = "ignored" });
            }

            var orderCodeString = orderCode.ToString();
            var payment = await _db.Payments
                .Include(p => p.Invoice)
                .FirstOrDefaultAsync(p => p.TransactionCode == orderCodeString);

            if (payment == null)
            {
                _logger.LogWarning("PayOS webhook order {Order} not found", orderCodeString);
                return Ok(new { message = "order not found" });
            }

            var statusCode = data?.Code;
            var paymentLinkId = data?.PaymentLinkId;

            if (statusCode == "00")
            {
                if (payment.Status != PaymentStatus.Success)
                {
                    payment.Status = PaymentStatus.Success;
                    payment.PaidAtUtc = DateTime.UtcNow;
                    payment.TransactionRef = paymentLinkId ?? payment.TransactionRef;
                    payment.ErrorCode = null;
                    payment.ErrorMessage = null;

                    await UpdateInvoiceStatus(payment.InvoiceId);
                    await _db.SaveChangesAsync();
                    await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
                }
            }
            else
            {
                payment.Status = PaymentStatus.Failed;
                payment.ErrorCode = statusCode;
                payment.ErrorMessage = "PayOS payment failed";
                await _db.SaveChangesAsync();
                await _paymentNotificationService.NotifyPaymentUpdatedAsync(payment);
            }

            return Ok(new { message = "processed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "PayOS webhook processing failed");
            return BadRequest();
        }
    }

    private async Task UpdateInvoiceStatus(Guid invoiceId)
    {
        var invoice = await _db.Invoices
            .Include(i => i.Apartment)
            .FirstOrDefaultAsync(i => i.Id == invoiceId);
        if (invoice == null) return;

        var totalPaid = await _db.Payments
            .Where(p => p.InvoiceId == invoiceId && p.Status == PaymentStatus.Success)
            .SumAsync(p => p.Amount);

        if (totalPaid >= invoice.TotalAmount)
        {
            invoice.Status = InvoiceStatus.Paid;

            if (invoice.Type == InvoiceType.Service)
            {
                var booking = await _db.AmenityBookings
                    .Where(b => b.UserId == invoice.UserId &&
                               b.StartTimeUtc.Date == invoice.PeriodStart.Date &&
                               b.EndTimeUtc.Date == invoice.PeriodEnd.Date &&
                               Math.Abs((b.Price ?? 0) - invoice.TotalAmount) < 0.01m &&
                               b.Status == AmenityBookingStatus.Pending)
                    .FirstOrDefaultAsync();

                if (booking != null)
                {
                    booking.Status = AmenityBookingStatus.Approved;
                    booking.PaymentStatus = PaymentStatus.Success;
                    await _db.SaveChangesAsync();
                }
            }
        }
        else if (totalPaid > 0)
        {
            invoice.Status = InvoiceStatus.PartiallyPaid;
        }
        else
        {
            invoice.Status = InvoiceStatus.Unpaid;
        }
    }
}

