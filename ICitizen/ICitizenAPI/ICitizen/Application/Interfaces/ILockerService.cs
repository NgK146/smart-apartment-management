using ICitizen.Domain;

namespace ICitizen.Application.Interfaces;

public interface ILockerService
{
    /// <summary>
    /// Security receives a package from shipper and creates a transaction
    /// </summary>
    Task<(bool Success, string Message, LockerTransaction? Transaction)> ReceivePackageAsync(
        string apartmentCode, string securityUserId, string? notes);
    
    /// <summary>
    /// Security opens compartment to drop package (audit only)
    /// </summary>
    Task<(bool Success, string Message)> OpenDropAsync(Guid transactionId, string userId);
    
    /// <summary>
    /// Security confirms package has been stored in locker, generates OTP
    /// </summary>
    Task<(bool Success, string Message, string? PickupOtp)> ConfirmStoredAsync(
        Guid transactionId, string securityUserId);
    
    /// <summary>
    /// Resident verifies OTP to authorize pickup
    /// </summary>
    Task<(bool Success, string Message)> VerifyPickupAsync(Guid transactionId, string token);
    
    /// <summary>
    /// Resident confirms they have picked up the package
    /// </summary>
    Task<(bool Success, string Message)> ConfirmPickedAsync(Guid transactionId, string residentUserId);
    
    /// <summary>
    /// Get transactions for a specific user (resident view)
    /// </summary>
    Task<List<LockerTransaction>> GetResidentTransactionsAsync(string userId, LockerTransactionStatus? status = null);
    
    /// <summary>
    /// Get transactions for security staff
    /// </summary>
    Task<List<LockerTransaction>> GetSecurityTransactionsAsync(LockerTransactionStatus? status = null);
    
    /// <summary>
    /// Generate 6-digit OTP
    /// </summary>
    string GenerateOtp();
    
    /// <summary>
    /// Hash token using SHA256
    /// </summary>
    string HashToken(string token);
}
