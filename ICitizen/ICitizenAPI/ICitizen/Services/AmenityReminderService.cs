using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Services;

/// <summary>
/// Đơn giản quét mỗi phút để nhắc cư dân trước giờ đặt tiện ích.
/// </summary>
public class AmenityReminderService : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<AmenityReminderService> _logger;

    public AmenityReminderService(IServiceProvider services, ILogger<AmenityReminderService> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                await ProcessRemindersAsync(stoppingToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "AmenityReminderService lỗi.");
            }
        }
    }

    private async Task ProcessRemindersAsync(CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var hub = scope.ServiceProvider.GetService<IHubContext<NotificationHub>>();

        var now = DateTime.UtcNow;
        var windowStart = now.AddMinutes(0);
        var windowEnd = now.AddMinutes(65); // chút buffer

        var bookings = await db.AmenityBookings
            .Include(b => b.Amenity)
            .Where(b => b.Status == AmenityBookingStatus.Approved
                        && b.StartTimeUtc >= windowStart
                        && b.StartTimeUtc <= windowEnd
                        && (b.ReminderSentAtUtc == null))
            .ToListAsync(ct);

        foreach (var b in bookings)
        {
            var targetTime = b.StartTimeUtc.AddMinutes(-b.ReminderOffsetMinutes);
            if (now >= targetTime)
            {
                b.ReminderSentAtUtc = now;
                
                // Tạo thông báo nhắc nhở với thông tin đầy đủ
                var amenityName = b.Amenity?.Name ?? "tiện ích";
                var startTimeVn = b.StartTimeUtc.AddHours(7); // Chuyển sang giờ Việt Nam
                var endTimeVn = b.EndTimeUtc.AddHours(7);
                var location = b.Amenity?.Location ?? "";
                var locationText = !string.IsNullOrWhiteSpace(location) ? $"\nĐịa điểm: {location}" : "";
                
                var reminderMessage = $"Còn {b.ReminderOffsetMinutes} phút sẽ bắt đầu sử dụng {amenityName}.\n" +
                                     $"Thời gian: {startTimeVn:dd/MM/yyyy HH:mm} - {endTimeVn:HH:mm}{locationText}";
                
                db.UserNotifications.Add(new UserNotification
                {
                    UserId = b.UserId,
                    Title = $"Nhắc nhở: {amenityName}",
                    Message = reminderMessage,
                    Type = "AmenityBooking",
                    RefType = "AmenityBookingReminder",
                    RefId = b.Id
                });
                await db.SaveChangesAsync(ct);

                if (hub != null)
                {
                    var unread = await db.UserNotifications.CountAsync(x => x.UserId == b.UserId && x.ReadAtUtc == null && !x.IsDeleted, ct);
                    await hub.Clients.Group($"user-{b.UserId}").SendAsync("userNotification", new
                    {
                        title = $"Nhắc nhở: {amenityName}",
                        message = reminderMessage,
                        type = "AmenityBooking",
                        refType = "AmenityBookingReminder",
                        refId = b.Id,
                        unreadCount = unread
                    }, ct);
                }
            }
        }
    }
}


