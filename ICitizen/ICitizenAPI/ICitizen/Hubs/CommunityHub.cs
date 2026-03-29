using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Hubs;

[Authorize]
public class CommunityHub : Hub
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<AppUser> _userManager;

    public CommunityHub(ApplicationDbContext db, UserManager<AppUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "general");
        await base.OnConnectedAsync();
    }

    public async Task JoinRoom(string room)
    {
        if (string.IsNullOrWhiteSpace(room)) return;
        await Groups.AddToGroupAsync(Context.ConnectionId, room);
    }

    public async Task LeaveRoom(string room)
    {
        if (string.IsNullOrWhiteSpace(room)) return;
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, room);
    }

    public async Task SendToRoom(string room, string message)
    {
        if (string.IsNullOrWhiteSpace(room) || string.IsNullOrWhiteSpace(message)) return;

        var trimmedRoom = room.Trim().ToLowerInvariant();
        var trimmedMessage = message.Trim();

        var senderId = Context.UserIdentifier ?? string.Empty;
        var senderName = "Ẩn danh";

        if (!string.IsNullOrEmpty(senderId))
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(u => u.Id == senderId);
            if (user != null)
            {
                senderName = user.FullName ?? user.UserName ?? senderName;
            }
        }

        var entity = new CommunityMessage
        {
            Room = trimmedRoom,
            SenderId = senderId,
            SenderName = senderName,
            Content = trimmedMessage
        };

        _db.CommunityMessages.Add(entity);
        await _db.SaveChangesAsync();

        await BroadcastMessageAsync(entity);
    }

    internal Task BroadcastMessageAsync(CommunityMessage entity)
    {
        return Clients.Group(entity.Room).SendAsync("message", new
        {
            id = entity.Id,
            room = entity.Room,
            senderId = entity.SenderId,
            senderName = entity.SenderName,
            content = entity.Content,
            attachmentType = entity.AttachmentType,
            attachmentUrl = entity.AttachmentUrl,
            attachmentDurationSeconds = entity.AttachmentDurationSeconds,
            createdAtUtc = entity.CreatedAtUtc
        });
    }
}

