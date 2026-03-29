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
public class ParkingPlansController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public ParkingPlansController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    public async Task<PagedResult<ParkingPlan>> List([FromQuery] QueryParameters p, [FromQuery] string? vehicleType = null, [FromQuery] bool? isActive = null)
    {
        var q = _db.ParkingPlans.AsQueryable();
        
        if (!string.IsNullOrWhiteSpace(vehicleType))
            q = q.Where(pp => pp.VehicleType == vehicleType);
        if (isActive.HasValue)
            q = q.Where(pp => pp.IsActive == isActive.Value);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(pp => pp.Name.Contains(p.Search) || (pp.Description ?? "").Contains(p.Search));
        
        return await q.OrderBy(x => x.Name).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ParkingPlan>> Get(Guid id)
    {
        var plan = await _db.ParkingPlans.FindAsync(id);
        if (plan == null) return NotFound();
        return plan;
    }

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<ParkingPlan>> Create(ParkingPlan plan)
    {
        _db.ParkingPlans.Add(plan);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = plan.Id }, plan);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, ParkingPlan plan)
    {
        var dbPlan = await _db.ParkingPlans.FindAsync(id);
        if (dbPlan == null) return NotFound();
        
        dbPlan.Name = plan.Name;
        dbPlan.Description = plan.Description;
        dbPlan.VehicleType = plan.VehicleType;
        dbPlan.Price = plan.Price;
        dbPlan.DurationInDays = plan.DurationInDays;
        dbPlan.IsActive = plan.IsActive;
        
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var plan = await _db.ParkingPlans.FindAsync(id);
        if (plan == null) return NotFound();
        
        _db.ParkingPlans.Remove(plan);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}

