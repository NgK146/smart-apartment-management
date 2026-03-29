using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Manager")]
public class LockersController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public LockersController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    public async Task<PagedResult<Locker>> List([FromQuery] QueryParameters p)
        => await _db.Lockers.Where(x => string.IsNullOrEmpty(p.Search) || x.Name.Contains(p.Search))
              .OrderBy(x => x.Name).ToPagedResultAsync(p.Page, p.PageSize);

    [HttpGet("{id}")]
    public async Task<ActionResult<Locker>> Get(Guid id)
        => await _db.Lockers.FindAsync(id) is { } m ? m : NotFound();

    [HttpPost]
    public async Task<ActionResult<Locker>> Create(Locker m)
    {
        _db.Lockers.Add(m); await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(Guid id, Locker m)
    {
        var dbm = await _db.Lockers.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Name = m.Name; dbm.Location = m.Location;
        await _db.SaveChangesAsync(); return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.Lockers.FindAsync(id);
        if (m is null) return NotFound();
        _db.Lockers.Remove(m); await _db.SaveChangesAsync(); return NoContent();
    }
}
