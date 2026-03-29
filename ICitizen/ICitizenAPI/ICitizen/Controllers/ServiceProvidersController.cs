using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ServiceProvidersController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public ServiceProvidersController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    public async Task<PagedResult<Domain.ServiceProvider>> List([FromQuery] QueryParameters p, [FromQuery] string? category = null)
    {
        var q = _db.ServiceProviders.Where(sp => sp.IsActive).AsQueryable();
        if (!string.IsNullOrWhiteSpace(category))
            q = q.Where(sp => sp.Category == category);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(sp => sp.Name.Contains(p.Search) || (sp.Description ?? "").Contains(p.Search));
        return await q.OrderBy(x => x.Name).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Domain.ServiceProvider>> Get(Guid id)
        => await _db.ServiceProviders.FindAsync(id) is { } m ? m : NotFound();

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<Domain.ServiceProvider>> Create(Domain.ServiceProvider m)
    {
        _db.ServiceProviders.Add(m);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, Domain.ServiceProvider m)
    {
        var dbm = await _db.ServiceProviders.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Name = m.Name;
        dbm.Category = m.Category;
        dbm.Phone = m.Phone;
        dbm.Email = m.Email;
        dbm.Address = m.Address;
        dbm.Description = m.Description;
        dbm.IsActive = m.IsActive;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.ServiceProviders.FindAsync(id);
        if (m is null) return NotFound();
        _db.ServiceProviders.Remove(m);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


