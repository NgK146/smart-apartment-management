using ICitizen.Application.Interfaces;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LockerController : ControllerBase
{
    private readonly ILockerService _lockerService;

    public LockerController(ILockerService lockerService)
    {
        _lockerService = lockerService;
    }

    /// <summary>
    /// Security receives package from shipper
    /// </summary>
    [HttpPost("receive")]
    [Authorize(Roles = "Security,Manager")]
    public async Task<IActionResult> ReceivePackage([FromBody] ReceivePackageRequest request)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        
        var (success, message, transaction) = await _lockerService.ReceivePackageAsync(
            request.ApartmentCode,
            userId,
            request.Notes);

        if (!success)
            return BadRequest(new { message });

        return Ok(new
        {
            message,
            transaction = new
            {
                transaction!.Id,
                transaction.ApartmentId,
                apartmentCode = transaction.Apartment?.Code,
                transaction.CompartmentId,
                compartmentCode = transaction.Compartment?.Code,
                transaction.Status,
                transaction.CreatedAtUtc
            }
        });
    }

    /// <summary>
    /// Security opens compartment for dropping package (audit only)
    /// </summary>
    [HttpPost("{id}/open-drop")]
    [Authorize(Roles = "Security,Manager")]
    public async Task<IActionResult> OpenDrop(Guid id)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        
        var (success, message) = await _lockerService.OpenDropAsync(id, userId);

        if (!success)
            return BadRequest(new { message });

        return Ok(new { message });
    }

    /// <summary>
    /// Security confirms package has been stored, returns OTP
    /// </summary>
    [HttpPost("{id}/confirm-stored")]
    [Authorize(Roles = "Security,Manager")]
    public async Task<IActionResult> ConfirmStored(Guid id)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        
        var (success, message, otp) = await _lockerService.ConfirmStoredAsync(id, userId);

        if (!success)
            return BadRequest(new { message });

        return Ok(new
        {
            message,
            otp,
            note = "OTP is displayed only once. Please provide it to the resident or it will be sent via notification."
        });
    }

    /// <summary>
    /// Resident verifies OTP before pickup
    /// </summary>
    [HttpPost("{id}/verify-pickup")]
    [Authorize(Roles = "Resident,Manager")]
    public async Task<IActionResult> VerifyPickup(Guid id, [FromBody] VerifyPickupRequest request)
    {
        var (success, message) = await _lockerService.VerifyPickupAsync(id, request.Otp);

        if (!success)
            return BadRequest(new { message });

        return Ok(new { message });
    }

    /// <summary>
    /// Resident confirms they have picked up the package
    /// </summary>
    [HttpPost("{id}/confirm-picked")]
    [Authorize(Roles = "Resident,Manager")]
    public async Task<IActionResult> ConfirmPicked(Guid id)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        
        var (success, message) = await _lockerService.ConfirmPickedAsync(id, userId);

        if (!success)
            return BadRequest(new { message });

        return Ok(new { message });
    }

    /// <summary>
    /// Resident views their packages
    /// </summary>
    [HttpGet("my-transactions")]
    [Authorize(Roles = "Resident,Manager")]
    public async Task<IActionResult> GetMyTransactions([FromQuery] LockerTransactionStatus? status = null)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value;
        
        var transactions = await _lockerService.GetResidentTransactionsAsync(userId, status);

        return Ok(transactions.Select(t => new
        {
            t.Id,
            t.ApartmentId,
            apartmentCode = t.Apartment?.Code,
            t.CompartmentId,
            compartmentCode = t.Compartment?.Code,
            t.Status,
            t.DropTime,
            t.PickupTime,
            t.PickupTokenExpireAt,
            t.Notes,
            t.CreatedAtUtc
        }));
    }

    /// <summary>
    /// Security views pending packages (default: ReceivedBySecurity)
    /// </summary>
    [HttpGet("security-transactions")]
    [Authorize(Roles = "Security,Manager")]
    public async Task<IActionResult> GetSecurityTransactions(
        [FromQuery] LockerTransactionStatus? status = LockerTransactionStatus.ReceivedBySecurity)
    {
        var transactions = await _lockerService.GetSecurityTransactionsAsync(status);

        return Ok(transactions.Select(t => new
        {
            t.Id,
            t.ApartmentId,
            apartmentCode = t.Apartment?.Code,
            t.CompartmentId,
            compartmentCode = t.Compartment?.Code,
            t.Status,
            t.DropTime,
            t.PickupTime,
            t.Notes,
            t.CreatedAtUtc
        }));
    }
}

// DTOs
public record ReceivePackageRequest(string ApartmentCode, string? Notes);
public record VerifyPickupRequest(string Otp);
