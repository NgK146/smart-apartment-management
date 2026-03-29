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
public class InternalTasksController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public InternalTasksController(ApplicationDbContext db) { _db = db; }

    // Manager xem tất cả; Staff xem của mình
    [HttpGet]
    public async Task<PagedResult<InternalTask>> List([FromQuery] QueryParameters p, 
        [FromQuery] InternalTaskStatus? status = null,
        [FromQuery] InternalTaskType? type = null,
        [FromQuery] bool? assignedToMe = null)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        var isManager = User.IsInRole("Manager");
        var q = _db.InternalTasks.Include(t => t.Apartment).AsQueryable();
        
        if (!isManager && assignedToMe == true && uid != null)
            q = q.Where(t => t.AssignedToUserId == uid);
        
        if (status.HasValue) q = q.Where(t => t.Status == status);
        if (type.HasValue) q = q.Where(t => t.Type == type);
        if (!string.IsNullOrWhiteSpace(p.Search))
            q = q.Where(t => t.Title.Contains(p.Search) || (t.Description ?? "").Contains(p.Search));
        
        return await q.OrderByDescending(x => x.CreatedAtUtc).ToPagedResultAsync(p.Page, p.PageSize);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<InternalTask>> Get(Guid id)
    {
        var task = await _db.InternalTasks.Include(t => t.Apartment).FirstOrDefaultAsync(t => t.Id == id);
        return task is null ? NotFound() : task;
    }

    [HttpPost]
    [Authorize(Roles = "Manager,Security,Vendor")]
    public async Task<ActionResult<InternalTask>> Create(InternalTask m)
    {
        var uid = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        m.CreatedByUserId = uid ?? string.Empty;
        _db.InternalTasks.Add(m);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager,Security,Vendor")]
    public async Task<IActionResult> Update(Guid id, InternalTask m)
    {
        var dbm = await _db.InternalTasks.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Title = m.Title;
        dbm.Description = m.Description;
        dbm.Type = m.Type;
        dbm.Priority = m.Priority;
        dbm.Status = m.Status;
        dbm.ApartmentId = m.ApartmentId;
        dbm.AssignedToUserId = m.AssignedToUserId;
        dbm.DueDate = m.DueDate;
        dbm.Notes = m.Notes;
        if (m.Status == InternalTaskStatus.Completed && dbm.Status != InternalTaskStatus.Completed)
            dbm.CompletedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPut("{id}/assign")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Assign(Guid id, [FromBody] string userId)
    {
        var task = await _db.InternalTasks.FindAsync(id);
        if (task is null) return NotFound();
        task.AssignedToUserId = userId;
        task.Status = InternalTaskStatus.InProgress;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPut("{id}/complete")]
    [Authorize(Roles = "Manager,Security,Vendor")]
    public async Task<IActionResult> Complete(Guid id)
    {
        var task = await _db.InternalTasks.FindAsync(id);
        if (task is null) return NotFound();
        task.Status = InternalTaskStatus.Completed;
        task.CompletedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.InternalTasks.FindAsync(id);
        if (m is null) return NotFound();
        _db.InternalTasks.Remove(m);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


