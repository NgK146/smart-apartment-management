using System.Security.Claims;
using ICitizen.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Hubs;

[Authorize]
public class SupportHub : Hub
{
    private readonly ApplicationDbContext _db;

    public SupportHub(ApplicationDbContext db)
    {
        _db = db;
    }

    private static bool IsManagerLike(ClaimsPrincipal? user) =>
        user != null && (user.IsInRole("Manager") || user.IsInRole("Security"));

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        if (!string.IsNullOrWhiteSpace(userId))
        {
            if (IsManagerLike(Context.User))
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, "support-staff");
            }

            var ticketIds = await _db.SupportTickets
                .Where(t => t.CreatedById == userId || t.AssignedToId == userId)
                .Select(t => t.Id)
                .ToListAsync();

            foreach (var ticketId in ticketIds)
            {
                await Groups.AddToGroupAsync(Context.ConnectionId, TicketGroup(ticketId));
            }
        }

        await base.OnConnectedAsync();
    }

    public async Task JoinTicket(Guid ticketId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, TicketGroup(ticketId));
    }

    private static string TicketGroup(Guid ticketId) => $"ticket-{ticketId}";
}

