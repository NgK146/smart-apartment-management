using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Linq;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/reports")]
    [Authorize(Roles = "Manager")]
    public class ReportsController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly ILogger<ReportsController> _logger;

        public ReportsController(ApplicationDbContext db, ILogger<ReportsController> logger)
        {
            _db = db;
            _logger = logger;
        }

        [HttpGet("overview")]
        public async Task<IActionResult> Overview()
        {
            try
            {
                var now = DateTime.UtcNow;
                var startOfMonth = new DateTime(now.Year, now.Month, 1);
                var startOfNextMonth = startOfMonth.AddMonths(1);
                var startOfPrevMonth = startOfMonth.AddMonths(-1);

                var startOfWeek = now.Date;
                // chuẩn hóa về thứ hai
                while (startOfWeek.DayOfWeek != DayOfWeek.Monday)
                {
                    startOfWeek = startOfWeek.AddDays(-1);
                }

                var newAccountsThisMonth = await _db.Users
                    .CountAsync(u => u.CreatedAtUtc >= startOfMonth);

                var activeAccountsThisWeek = await _db.Users
                    .CountAsync(u => u.IsApproved && u.CreatedAtUtc >= startOfWeek);

                var totalApartments = await _db.Apartments.CountAsync();
                var occupiedApartmentIds = await _db.ResidentProfiles
                    .Where(r => r.IsVerifiedByBQL)
                    .Select(r => r.ApartmentId)
                    .ToListAsync();

                var occupiedApartments = occupiedApartmentIds.Distinct().Count();
                var vacantApartments = Math.Max(totalApartments - occupiedApartments, 0);

                var complaintsPending = await _db.Complaints.CountAsync(c => c.Status == ComplaintStatus.Pending);
                var overdueThreshold = now.AddDays(-3);
                var complaintsOverdue = await _db.Complaints
                    .CountAsync(c => c.Status == ComplaintStatus.Pending && c.CreatedAtUtc < overdueThreshold);

                var collectedPaymentsThisMonth = await _db.Payments
                    .Where(p => p.Status == PaymentStatus.Success &&
                                p.PaidAtUtc >= startOfMonth && p.PaidAtUtc < startOfNextMonth)
                    .ToListAsync();
                var collectedThisMonth = collectedPaymentsThisMonth.Sum(p => p.Amount);

                var invoicesThisMonth = await _db.Invoices
                    .Where(i => i.CreatedAtUtc >= startOfMonth && i.CreatedAtUtc < startOfNextMonth)
                    .Select(i => new { i.Id, i.TotalAmount, i.PeriodEnd })
                    .ToListAsync();

                var paymentsByInvoice = await _db.Payments
                    .Where(p => p.Status == PaymentStatus.Success)
                    .Join(_db.Invoices
                        .Where(i => i.CreatedAtUtc >= startOfMonth && i.CreatedAtUtc < startOfNextMonth)
                        .Select(i => new { i.Id }),
                        p => p.InvoiceId,
                        i => i.Id,
                        (p, i) => new { p.InvoiceId, p.Amount })
                    .ToListAsync();
                var paidLookup = paymentsByInvoice
                    .GroupBy(p => p.InvoiceId)
                    .ToDictionary(g => g.Key, g => g.Sum(p => p.Amount));

                decimal outstandingThisMonth = 0m;
                decimal overdueAmount = 0m;
                foreach (var invoice in invoicesThisMonth)
                {
                    var paid = paidLookup.TryGetValue(invoice.Id, out var value) ? value : 0m;
                    var remaining = Math.Max(invoice.TotalAmount - paid, 0m);
                    outstandingThisMonth += remaining;
                    if (remaining > 0 && invoice.PeriodEnd.Date < now.Date)
                    {
                        overdueAmount += remaining;
                    }
                }

                var previousMonthCollectedPayments = await _db.Payments
                    .Where(p => p.Status == PaymentStatus.Success &&
                                p.PaidAtUtc >= startOfPrevMonth && p.PaidAtUtc < startOfMonth)
                    .ToListAsync();
                var previousMonthCollected = previousMonthCollectedPayments.Sum(p => p.Amount);

                var trendStart = now.Date.AddDays(-6);
                var trendDates = Enumerable.Range(0, 7).Select(i => trendStart.AddDays(i)).ToList();

                var complaintsTrendRaw = await _db.Complaints
                    .Where(c => c.CreatedAtUtc >= trendStart)
                    .ToListAsync();
                var complaintsTrendData = complaintsTrendRaw
                    .GroupBy(c => c.CreatedAtUtc.Date)
                    .ToDictionary(g => g.Key, g => g.Count());

                var supportTrendRaw = await _db.SupportTickets
                    .Where(t => t.CreatedAtUtc >= trendStart)
                    .ToListAsync();
                var supportTrendData = supportTrendRaw
                    .GroupBy(t => t.CreatedAtUtc.Date)
                    .ToDictionary(g => g.Key, g => g.Count());

                var interaction = trendDates.Select(d => new
                {
                    date = d.ToString("yyyy-MM-dd"),
                    complaints = complaintsTrendData.TryGetValue(d, out var complaintCount) ? complaintCount : 0,
                    tickets = supportTrendData.TryGetValue(d, out var ticketCount) ? ticketCount : 0
                }).ToList();

                var pendingAccountApprovals = await _db.Users.CountAsync(u => !u.IsApproved);
                var pendingResidentApprovals = await _db.ResidentProfiles.CountAsync(r => !r.IsVerifiedByBQL);
                var pendingApprovals = pendingAccountApprovals + pendingResidentApprovals;

                var activeTicketIds = await _db.SupportTickets
                    .Where(t => t.Status != SupportTicketStatus.Closed && t.Status != SupportTicketStatus.Resolved)
                    .Select(t => t.Id)
                    .ToListAsync();

                var lastMessagesRaw = await _db.SupportTicketMessages
                    .Where(m => activeTicketIds.Contains(m.TicketId))
                    .ToListAsync();
                var unreadSupportTickets = lastMessagesRaw
                    .GroupBy(m => m.TicketId)
                    .Select(g => g.OrderByDescending(m => m.CreatedAtUtc).FirstOrDefault())
                    .Count(m => m != null && !m.IsFromStaff);

                return Ok(new
                {
                    accounts = new
                    {
                        newThisMonth = newAccountsThisMonth,
                        activeThisWeek = activeAccountsThisWeek
                    },
                    apartments = new
                    {
                        occupied = occupiedApartments,
                        vacant = vacantApartments,
                        total = totalApartments
                    },
                    complaints = new
                    {
                        pending = complaintsPending,
                        overdue = complaintsOverdue
                    },
                    finance = new
                    {
                        collectedThisMonth,
                        outstandingThisMonth,
                        overdueAmount,
                        revenueTrend = new
                        {
                            currentMonth = collectedThisMonth,
                            previousMonth = previousMonthCollected
                        }
                    },
                    interaction,
                    quickActions = new
                    {
                        overdueComplaints = complaintsOverdue,
                        pendingApprovals,
                        unreadSupportTickets
                    }
                });
            }
            catch (Exception ex)
            {
                return ApiResponseHelper.HandleException(ex, "Lỗi khi tải tổng quan", _logger);
            }
        }
    }
}
