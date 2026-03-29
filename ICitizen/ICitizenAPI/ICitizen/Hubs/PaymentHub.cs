using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ICitizen.Hubs;

[Authorize]
public class PaymentHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        if (!string.IsNullOrEmpty(userId))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        }

        if (Context.User?.IsInRole("Manager") == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "managers");
        }

        await base.OnConnectedAsync();
    }
}


