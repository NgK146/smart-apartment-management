using System.Security.Cryptography;
using System.Text;
using ICitizen.Application.Interfaces;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace ICitizen.Services;

public class LockerService : ILockerService
{
    private readonly ApplicationDbContext _db;
    private readonly IConfiguration _config;
    private readonly IHubContext<LockerHub> _lockerHub;

    public LockerService(
        ApplicationDbContext db,
        IConfiguration config,
        IHubContext<LockerHub> lockerHub)
    {
        _db = db;
        _config = config;
        _lockerHub = lockerHub;
    }

    public async Task<(bool Success, string Message, LockerTransaction? Transaction)> ReceivePackageAsync(
        string apartmentCode, string securityUserId, string? notes)
    {
        // Find apartment
        var apartment = await _db.Apartments
            .Include(a => a.Compartment)
            .FirstOrDefaultAsync(a => a.Code == apartmentCode);

        if (apartment == null)
            return (false, $"Apartment '{apartmentCode}' not found", null);

        if (apartment.Compartment == null)
            return (false, $"No locker compartment assigned to apartment '{apartmentCode}'", null);

        // Check if compartment is occupied
        if (apartment.Compartment.Status == CompartmentStatus.Occupied)
            return (false, $"Ngăn tủ {apartment.Compartment.Code} của căn hộ {apartmentCode} đang có hàng. Vui lòng đợi cư dân lấy hàng trước khi nhận hàng mới.", null);

        // Create transaction
        var transaction = new LockerTransaction
        {
            ApartmentId = apartment.Id,
            CompartmentId = apartment.Compartment.Id,
            SecurityUserId = securityUserId,
            Status = LockerTransactionStatus.ReceivedBySecurity,
            Notes = notes
        };

        _db.LockerTransactions.Add(transaction);

        // Audit log
        _db.AuditLogs.Add(new AuditLog
        {
            TransactionId = transaction.Id,
            Action = "RECEIVE_PACKAGE",
            ByUserId = securityUserId,
            At = DateTime.UtcNow,
            Note = $"Received package for apartment {apartmentCode}"
        });

        await _db.SaveChangesAsync();

        // Load navigation properties for response
        await _db.Entry(transaction).Reference(t => t.Apartment).LoadAsync();
        await _db.Entry(transaction).Reference(t => t.Compartment).LoadAsync();

        return (true, $"Package received successfully. Compartment: {apartment.Compartment.Code}", transaction);
    }

    public async Task<(bool Success, string Message)> OpenDropAsync(Guid transactionId, string userId)
    {
        var transaction = await _db.LockerTransactions.FindAsync(transactionId);
        if (transaction == null)
            return (false, "Transaction not found");

        if (transaction.Status != LockerTransactionStatus.ReceivedBySecurity)
            return (false, "Invalid transaction status. Package must be in 'ReceivedBySecurity' state.");

        // Audit log only - no status change
        _db.AuditLogs.Add(new AuditLog
        {
            TransactionId = transactionId,
            Action = "OPEN_DROP",
            ByUserId = userId,
            At = DateTime.UtcNow,
            Note = "Opened compartment to drop package"
        });

        await _db.SaveChangesAsync();

        return (true, "Compartment opened. Please place the package inside.");
    }

    public async Task<(bool Success, string Message, string? PickupOtp)> ConfirmStoredAsync(
        Guid transactionId, string securityUserId)
    {
        var transaction = await _db.LockerTransactions
            .Include(t => t.Compartment)
            .Include(t => t.Apartment)
            .FirstOrDefaultAsync(t => t.Id == transactionId);

        if (transaction == null)
            return (false, "Transaction not found", null);

        if (transaction.Status != LockerTransactionStatus.ReceivedBySecurity)
            return (false, "Invalid transaction status", null);

        // Generate OTP
        var otp = GenerateOtp();
        var otpHash = HashToken(otp);

        // Get expiration hours from config
        var expireHours = _config.GetValue<int>("Locker:OtpExpireHours", 24);

        // Update transaction
        transaction.Status = LockerTransactionStatus.Stored;
        transaction.DropTime = DateTime.UtcNow;
        transaction.PickupTokenHash = otpHash;
        transaction.PickupTokenExpireAt = DateTime.UtcNow.AddHours(expireHours);

        // Update compartment status
        transaction.Compartment!.Status = CompartmentStatus.Occupied;

        // Audit log
        _db.AuditLogs.Add(new AuditLog
        {
            TransactionId = transactionId,
            Action = "CONFIRM_STORED",
            ByUserId = securityUserId,
            At = DateTime.UtcNow,
            Note = "Package stored in locker"
        });

        await _db.SaveChangesAsync();

        // Send real-time notification to resident via SignalR
        // Find resident user IDs for this apartment
        var residentUserIds = await _db.ResidentProfiles
            .Where(r => r.ApartmentId == transaction.ApartmentId)
            .Select(r => r.UserId)
            .ToListAsync();

        foreach (var userId in residentUserIds)
        {
            try
            {
                await _lockerHub.Clients.Group($"user:{userId}")
                    .SendAsync("PackageStored", new
                    {
                        transactionId = transaction.Id,
                        apartmentCode = transaction.Apartment?.Code,
                        compartmentCode = transaction.Compartment.Code,
                        otp = otp,
                        expiresAt = transaction.PickupTokenExpireAt,
                        message = "Your package has been stored in the locker"
                    });
            }
            catch (Exception)
            {
                // Log but don't fail if SignalR fails
            }
        }

        // Create persistent notification in database for residents
        foreach (var userId in residentUserIds)
        {
            var notification = new UserNotification
            {
                UserId = userId,
                Title = "📦 Gói hàng đã được gửi đến",
                Message = $"Gói hàng của bạn đã được lưu tại ngăn {transaction.Compartment.Code}. " +
                          $"Mã OTP để lấy hàng: {otp}. " +
                          $"Mã có hiệu lực đến {transaction.PickupTokenExpireAt.Value.AddHours(7):dd/MM/yyyy HH:mm}.",
                Type = "LockerPackage",
                RefType = "LockerTransactionStored",
                RefId = transaction.Id,
                CreatedAtUtc = DateTime.UtcNow,
                ReadAtUtc = null
            };
            
            _db.UserNotifications.Add(notification);
        }

        await _db.SaveChangesAsync();

        return (true, "Package stored successfully", otp);
    }

    public async Task<(bool Success, string Message)> VerifyPickupAsync(Guid transactionId, string token)
    {
        var transaction = await _db.LockerTransactions.FindAsync(transactionId);
        if (transaction == null)
            return (false, "Transaction not found");

        if (transaction.Status != LockerTransactionStatus.Stored)
            return (false, "Package not ready for pickup");

        // Check expiration
        if (transaction.PickupTokenExpireAt.HasValue &&
            transaction.PickupTokenExpireAt.Value < DateTime.UtcNow)
        {
            transaction.Status = LockerTransactionStatus.Expired;
            await _db.SaveChangesAsync();
            return (false, "OTP has expired");
        }

        // Verify token hash
        var tokenHash = HashToken(token);
        if (transaction.PickupTokenHash != tokenHash)
            return (false, "Invalid OTP");

        return (true, "OTP verified successfully. You may now pick up your package.");
    }

    public async Task<(bool Success, string Message)> ConfirmPickedAsync(
        Guid transactionId, string residentUserId)
    {
        var transaction = await _db.LockerTransactions
            .Include(t => t.Compartment)
            .FirstOrDefaultAsync(t => t.Id == transactionId);

        if (transaction == null)
            return (false, "Transaction not found");

        if (transaction.Status != LockerTransactionStatus.Stored)
            return (false, "Package not ready for pickup");

        // Update transaction
        transaction.Status = LockerTransactionStatus.PickedUp;
        transaction.PickupTime = DateTime.UtcNow;
        
        // IMPORTANT: Invalidate OTP after pickup (one-time use)
        transaction.PickupTokenHash = null;

        // Update compartment
        transaction.Compartment!.Status = CompartmentStatus.Empty;

        // Audit log
        _db.AuditLogs.Add(new AuditLog
        {
            TransactionId = transactionId,
            Action = "CONFIRM_PICKED",
            ByUserId = residentUserId,
            At = DateTime.UtcNow,
            Note = "Package picked up by resident"
        });

        await _db.SaveChangesAsync();

        return (true, "Package picked up successfully");
    }

    public async Task<List<LockerTransaction>> GetResidentTransactionsAsync(
        string userId, LockerTransactionStatus? status = null)
    {
        // Find apartments for this user
        var apartmentIds = await _db.ResidentProfiles
            .Where(r => r.UserId == userId)
            .Select(r => r.ApartmentId)
            .ToListAsync();

        var query = _db.LockerTransactions
            .Include(t => t.Apartment)
            .Include(t => t.Compartment)
            .Where(t => apartmentIds.Contains(t.ApartmentId));

        if (status.HasValue)
            query = query.Where(t => t.Status == status.Value);

        return await query
            .OrderByDescending(t => t.CreatedAtUtc)
            .ToListAsync();
    }

    public async Task<List<LockerTransaction>> GetSecurityTransactionsAsync(
        LockerTransactionStatus? status = null)
    {
        var query = _db.LockerTransactions
            .Include(t => t.Apartment)
            .Include(t => t.Compartment)
            .AsQueryable();

        if (status.HasValue)
            query = query.Where(t => t.Status == status.Value);

        return await query
            .OrderByDescending(t => t.CreatedAtUtc)
            .ToListAsync();
    }

    public string GenerateOtp()
    {
        // Generate 6-digit numeric OTP
        var random = new Random();
        return random.Next(100000, 999999).ToString();
    }

    public string HashToken(string token)
    {
        using var sha256 = SHA256.Create();
        var bytes = Encoding.UTF8.GetBytes(token);
        var hash = sha256.ComputeHash(bytes);
        return Convert.ToBase64String(hash);
    }
}
