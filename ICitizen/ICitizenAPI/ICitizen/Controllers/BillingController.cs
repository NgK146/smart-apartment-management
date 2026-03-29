using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Manager")]
public class BillingController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly IInvoicePaymentService _invoicePaymentService;
    private readonly ILogger<BillingController> _logger;
    public BillingController(ApplicationDbContext db, IInvoicePaymentService invoicePaymentService, ILogger<BillingController> logger)
    {
        _db = db;
        _invoicePaymentService = invoicePaymentService;
        _logger = logger;
    }

    // POST /api/billing/meter-readings: BQL nhập chỉ số điện/nước
    public record MeterReadingDto(Guid ApartmentId, Guid FeeDefinitionId, decimal Reading);
    public record MeterReadingsRequest(int Month, int Year, List<MeterReadingDto> Readings);

    [HttpPost("meter-readings")]
    public async Task<IActionResult> CreateMeterReadings([FromBody] MeterReadingsRequest req)
    {
        var results = new List<MeterReading>();

        foreach (var dto in req.Readings)
        {
            // Tìm chỉ số tháng trước
            var previousReading = await _db.MeterReadings
                .Where(mr => mr.ApartmentId == dto.ApartmentId 
                    && mr.FeeDefinitionId == dto.FeeDefinitionId
                    && (mr.Year < req.Year || (mr.Year == req.Year && mr.Month < req.Month)))
                .OrderByDescending(mr => mr.Year)
                .ThenByDescending(mr => mr.Month)
                .FirstOrDefaultAsync();

            var meterReading = new MeterReading
            {
                ApartmentId = dto.ApartmentId,
                FeeDefinitionId = dto.FeeDefinitionId,
                Month = req.Month,
                Year = req.Year,
                Reading = dto.Reading,
                PreviousReading = previousReading?.Reading ?? 0m
            };

            _db.MeterReadings.Add(meterReading);
            results.Add(meterReading);
        }

        await _db.SaveChangesAsync();
        return Ok(results);
    }

    // POST /api/billing/generate-invoices: Tạo hóa đơn hàng loạt
    public record GenerateInvoicesRequest(int Month, int Year, DateTime DueDate);

    [HttpPost("generate-invoices")]
    public async Task<IActionResult> GenerateInvoices([FromBody] GenerateInvoicesRequest req)
    {
        var invoices = await GenerateInvoicesInternal(req.Month, req.Year, req.DueDate, InvoiceType.ManagementFee, HttpContext);
        // Chỉ trả về số lượng để tránh vòng lặp JSON khi serialize toàn bộ graph Invoice -> Apartment -> Residents...
        return Ok(new { Count = invoices.Count });
    }

    public record GenerateManagementFeesRequest(int Month, int Year);

    [HttpPost("generate-management-fees")]
    public async Task<IActionResult> GenerateManagementFees([FromBody] GenerateManagementFeesRequest req)
    {
        var dueDay = Math.Min(10, DateTime.DaysInMonth(req.Year, req.Month));
        var dueDate = new DateTime(req.Year, req.Month, dueDay);
        var invoices = await GenerateInvoicesInternal(req.Month, req.Year, dueDate, InvoiceType.ManagementFee, HttpContext);
        // Frontend chỉ cần "count", không cần danh sách đầy đủ -> tránh lỗi vòng lặp JSON
        return Ok(new { count = invoices.Count });
    }

    private async Task<List<Invoice>> GenerateInvoicesInternal(int month, int year, DateTime dueDate, InvoiceType type, HttpContext httpContext)
    {
        var apartments = await _db.Apartments
            .Where(a => a.Status == ApartmentStatus.Occupied && !a.IsDeleted)
            .ToListAsync();

        var feeDefinitions = await _db.FeeDefinitions
            .Where(f => f.IsActive && !f.IsDeleted)
            .ToListAsync();

        var invoices = new List<Invoice>();
        var periodStart = new DateTime(year, month, 1);
        var periodEnd = periodStart.AddMonths(1).AddDays(-1);

        foreach (var apartment in apartments)
        {
            var exists = await _db.Invoices.AnyAsync(i =>
                i.ApartmentId == apartment.Id &&
                i.Month == month &&
                i.Year == year &&
                i.Type == type);
            if (exists) continue;

            var invoice = new Invoice
            {
                ApartmentId = apartment.Id,
                Month = month,
                Year = year,
                PeriodStart = periodStart,
                PeriodEnd = periodEnd,
                DueDate = dueDate,
                Status = InvoiceStatus.Unpaid,
                Type = type,
                Lines = new List<InvoiceLine>(),
                TotalAmount = 0m
            };

            var resident = await _db.ResidentProfiles
                .FirstOrDefaultAsync(r => r.ApartmentId == apartment.Id && !r.IsDeleted);
            if (resident != null)
                invoice.UserId = resident.UserId;

            foreach (var fee in feeDefinitions)
            {
                decimal amount = 0m;
                string description = string.Empty;
                decimal quantity = 1m;

                switch (fee.CalculationMethod)
                {
                    case FeeCalculationMethod.Fixed:
                        amount = fee.Amount;
                        description = fee.Name;
                        break;

                    case FeeCalculationMethod.PerM2:
                        if (apartment.AreaM2.HasValue)
                        {
                            quantity = apartment.AreaM2.Value;
                            amount = apartment.AreaM2.Value * fee.Amount;
                            description = $"{apartment.AreaM2.Value}m² x {fee.Amount:N0}đ";
                        }
                        break;

                    case FeeCalculationMethod.PerUnit:
                        if (resident != null)
                        {
                            var vehicleCount = await _db.Vehicles
                                .CountAsync(v => v.ResidentProfileId == resident.Id
                                    && v.Status == "Approved"
                                    && !v.IsDeleted);
                            quantity = vehicleCount;
                            amount = vehicleCount * fee.Amount;
                            description = $"{vehicleCount} xe x {fee.Amount:N0}đ";
                        }
                        break;

                    case FeeCalculationMethod.Metered:
                        var meterReading = await _db.MeterReadings
                            .FirstOrDefaultAsync(mr => mr.ApartmentId == apartment.Id
                                && mr.FeeDefinitionId == fee.Id
                                && mr.Month == month
                                && mr.Year == year);
                        if (meterReading != null)
                        {
                            quantity = meterReading.Usage;
                            amount = meterReading.Usage * fee.Amount;
                            description = $"{meterReading.Usage:N2} kWh x {fee.Amount:N0}đ";
                        }
                        break;
                }

                if (amount > 0)
                {
                    invoice.Lines.Add(new InvoiceLine
                    {
                        FeeDefinitionId = fee.Id,
                        FeeName = fee.Name,
                        Description = description,
                        Quantity = quantity,
                        UnitPrice = fee.Amount,
                        Amount = amount
                    });
                }
            }

            invoice.TotalAmount = invoice.Lines.Sum(l => l.Amount);

            if (invoice.TotalAmount > 0)
            {
                _db.Invoices.Add(invoice);
                invoices.Add(invoice);
            }
        }

        await _db.SaveChangesAsync();

        foreach (var invoice in invoices)
        {
            try
            {
                await _invoicePaymentService.EnsureVnPayPaymentAsync(invoice, httpContext);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể tạo QR thanh toán cho hóa đơn {InvoiceId}", invoice.Id);
            }
        }
        return invoices;
    }
}

