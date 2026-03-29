using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RentalContractsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public RentalContractsController(ApplicationDbContext db) { _db = db; }

    // Manager xem tất cả; Resident xem của mình
    [HttpGet]
    public async Task<PagedResult<RentalContract>> List([FromQuery] QueryParameters p, [FromQuery] RentalContractStatus? status = null)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        var q = _db.RentalContracts.Include(rc => rc.Apartment).Include(rc => rc.ResidentProfile).AsQueryable();
        
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile != null) q = q.Where(rc => rc.ResidentProfileId == profile.Id);
        }
        
        if (status.HasValue) q = q.Where(rc => rc.Status == status);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(rc => rc.ContractNumber.Contains(p.Search) || (rc.Apartment != null && rc.Apartment.Code.Contains(p.Search)));
        
        return await q.OrderByDescending(x => x.CreatedAtUtc).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<RentalContract>> Get(Guid id)
    {
        var contract = await _db.RentalContracts.Include(rc => rc.Apartment).Include(rc => rc.ResidentProfile)
            .FirstOrDefaultAsync(rc => rc.Id == id);
        if (contract is null) return NotFound();
        
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        if (!isManager && uid != null)
        {
            var profile = await _db.ResidentProfiles.FirstOrDefaultAsync(r => r.UserId == uid);
            if (profile == null || contract.ResidentProfileId != profile.Id) return Forbid();
        }
        
        return contract;
    }

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<RentalContract>> Create(RentalContract m)
    {
        _db.RentalContracts.Add(m);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, RentalContract m)
    {
        var dbm = await _db.RentalContracts.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.ContractNumber = m.ContractNumber;
        dbm.ApartmentId = m.ApartmentId;
        dbm.ResidentProfileId = m.ResidentProfileId;
        dbm.StartDate = m.StartDate;
        dbm.EndDate = m.EndDate;
        dbm.MonthlyRent = m.MonthlyRent;
        dbm.Deposit = m.Deposit;
        dbm.Terms = m.Terms;
        dbm.Status = m.Status;
        dbm.SignedAtUtc = m.SignedAtUtc;
        dbm.SignedByUserId = m.SignedByUserId;
        dbm.DocumentUrl = m.DocumentUrl;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPut("{id}/sign")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Sign(Guid id)
    {
        var contract = await _db.RentalContracts.FindAsync(id);
        if (contract is null) return NotFound();
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        contract.Status = RentalContractStatus.Active;
        contract.SignedAtUtc = DateTime.UtcNow;
        contract.SignedByUserId = uid;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.RentalContracts.FindAsync(id);
        if (m is null) return NotFound();
        _db.RentalContracts.Remove(m);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


