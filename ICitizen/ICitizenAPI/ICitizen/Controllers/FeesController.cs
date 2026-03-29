using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Manager")]
public class FeesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public FeesController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    public async Task<PagedResult<FeeDefinition>> List([FromQuery] QueryParameters p, [FromQuery] bool? isActive = null)
    {
        var q = _db.FeeDefinitions.AsQueryable();
        if (!string.IsNullOrEmpty(p.Search))
            q = q.Where(x => x.Name.Contains(p.Search) || (x.Description != null && x.Description.Contains(p.Search)));
        if (isActive.HasValue)
            q = q.Where(x => x.IsActive == isActive.Value);
        q = q.Where(x => !x.IsDeleted);
        return await q.OrderBy(x => x.Name).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<FeeDefinition>> Get(Guid id)
        => await _db.FeeDefinitions.FindAsync(id) is { } m ? m : NotFound();

    [HttpPost]
    public async Task<ActionResult<FeeDefinition>> Create(FeeDefinition m)
    {
        _db.FeeDefinitions.Add(m); await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(Guid id, FeeDefinition m)
    {
        var dbm = await _db.FeeDefinitions.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Name = m.Name; 
        dbm.Description = m.Description; 
        dbm.Amount = m.Amount; 
        dbm.CalculationMethod = m.CalculationMethod;
        dbm.PeriodType = m.PeriodType; 
        dbm.IsActive = m.IsActive;
        await _db.SaveChangesAsync(); 
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.FeeDefinitions.FindAsync(id);
        if (m is null) return NotFound();
        m.IsDeleted = true; // Soft delete
        await _db.SaveChangesAsync(); 
        return NoContent();
    }
}
