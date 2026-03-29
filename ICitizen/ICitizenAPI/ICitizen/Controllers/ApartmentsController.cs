using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ApartmentsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public ApartmentsController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> List([FromQuery] QueryParameters p)
    {
        try
        {
            var q = _db.Apartments.AsQueryable();
            if (!string.IsNullOrWhiteSpace(p.Search)) q = q.Where(x => x.Code.Contains(p.Search) || x.Building.Contains(p.Search));
            
            var apartments = await q
                .OrderBy(x => x.Code)
                .Select(a => new
                {
                    a.Id,
                    a.Code,
                    a.Building,
                    a.Floor,
                    a.AreaM2,
                    a.Status,
                    HasVerifiedResident = a.Residents.Any(r => r.IsVerifiedByBQL)
                })
                .ToListAsync();

            var items = apartments
                .Skip((p.Page - 1) * p.PageSize)
                .Take(p.PageSize)
                .Select(a => new
                {
                    id = a.Id,
                    code = a.Code,
                    building = a.Building,
                    floor = a.Floor,
                    areaM2 = a.AreaM2,
                    status = ResolveStatus(a.Status, a.HasVerifiedResident).ToString()
                })
                .ToList();

            return Ok(new { items, total = apartments.Count, page = p.Page, pageSize = p.PageSize });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách căn hộ", message = ex.Message });
        }
    }

    // API public để lấy danh sách căn hộ cho dropdown (không cần đăng nhập)
    [HttpGet("available")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAvailableApartments()
    {
        var apartments = await _db.Apartments
            .Where(a => !a.IsDeleted && a.Status == ApartmentStatus.Available)
            .OrderBy(a => a.Code)
            .Select(a => new
            {
                id = a.Id,
                code = a.Code,
                building = a.Building,
                floor = a.Floor,
                areaM2 = a.AreaM2,
                status = a.Status.ToString() // Thêm status để frontend biết
            })
            .ToListAsync();
        
        return Ok(apartments);
    }

    // API cho Resident để xem tất cả căn hộ với status đầy đủ
    [HttpGet("list")]
    [Authorize]
    public async Task<IActionResult> ListForResident([FromQuery] QueryParameters p)
    {
        try
        {
            var q = _db.Apartments
                .Where(a => !a.IsDeleted)
                .AsQueryable();
            if (!string.IsNullOrWhiteSpace(p.Search)) 
                q = q.Where(x => x.Code.Contains(p.Search) || x.Building.Contains(p.Search));
            
            var apartments = await q
                .OrderBy(x => x.Code)
                .Select(a => new
                {
                    a.Id,
                    a.Code,
                    a.Building,
                    a.Floor,
                    a.AreaM2,
                    a.Status,
                    HasVerifiedResident = a.Residents.Any(r => r.IsVerifiedByBQL)
                })
                .ToListAsync();
            
            var result = apartments
                .Skip((p.Page - 1) * p.PageSize)
                .Take(p.PageSize)
                .Select(a => new
                {
                    id = a.Id,
                    code = a.Code,
                    building = a.Building,
                    floor = a.Floor,
                    areaM2 = a.AreaM2,
                    status = ResolveStatus(a.Status, a.HasVerifiedResident).ToString() // Trả về status đầy đủ
                })
                .ToList();
            
            return Ok(new { items = result, total = apartments.Count, page = p.Page, pageSize = p.PageSize });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách căn hộ", message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    [Authorize]
    public async Task<ActionResult<Apartment>> Get(Guid id)
    {
        var ap = await _db.Apartments.FindAsync(id);
        return ap is null ? NotFound() : ap;
    }

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<Apartment>> Create(Apartment m)
    {
        _db.Apartments.Add(m); await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, Apartment m)
    {
        var dbm = await _db.Apartments.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Code = m.Code; dbm.Building = m.Building; dbm.Floor = m.Floor; dbm.AreaM2 = m.AreaM2; dbm.Status = m.Status;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.Apartments.FindAsync(id);
        if (m is null) return NotFound();
        _db.Apartments.Remove(m); await _db.SaveChangesAsync(); return NoContent();
    }
    private static ApartmentStatus ResolveStatus(ApartmentStatus current, bool hasVerifiedResident)
    {
        if (current == ApartmentStatus.Maintenance || current == ApartmentStatus.Reserved)
        {
            return current;
        }
        return hasVerifiedResident ? ApartmentStatus.Occupied : ApartmentStatus.Available;
    }
}
