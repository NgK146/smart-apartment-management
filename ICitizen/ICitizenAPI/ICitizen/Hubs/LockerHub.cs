using Microsoft.AspNetCore.SignalR;

namespace ICitizen.Hubs;

public class LockerHub : Hub
{
    /// <summary>
    /// Client calls this when connecting to join their personal group
    /// </summary>
    public async Task JoinUserGroup(string userId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
    }
    
    /// <summary>
    /// Client leaves their user group (optional, called on disconnect)
    /// </summary>
    public async Task LeaveUserGroup(string userId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"user:{userId}");
    }
}
