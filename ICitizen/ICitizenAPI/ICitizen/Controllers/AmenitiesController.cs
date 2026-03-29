using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AmenitiesController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    public AmenitiesController(ApplicationDbContext db) { _db = db; }

    [HttpGet]
    [Authorize]
    public async Task<IActionResult> List([FromQuery] QueryParameters p)
    {
        try
        {
            var query = _db.Amenities.Where(a => !a.IsDeleted).AsQueryable();
            
            // Filter theo search
            if (!string.IsNullOrEmpty(p.Search))
            {
                query = query.Where(a => a.Name.Contains(p.Search) || 
                                        (a.Description != null && a.Description.Contains(p.Search)));
            }
            
            // Filter theo category
            if (!string.IsNullOrEmpty(p.Category))
            {
                query = query.Where(a => a.Category == p.Category);
            }
            
            var result = await query
                .OrderBy(a => a.Name)
                .ToPagedResultAsync(p.Page, p.PageSize);
                
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách tiện ích", message = ex.Message });
        }
    }

    /// <summary>
    /// Lấy danh sách categories từ Amenities hoặc Categories table
    /// GET /api/Amenities/categories
    /// </summary>
    [HttpGet("categories")]
    [Authorize]
    public async Task<IActionResult> GetCategories()
    {
        try
        {
            // Ưu tiên lấy từ bảng Categories
            var categories = await _db.Categories
                .Where(c => c.IsActive && !c.IsDeleted)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => c.Name)
                .ToListAsync();
            
            // Nếu chưa có categories trong bảng Categories, lấy từ Amenities
            if (!categories.Any())
            {
                categories = await _db.Amenities
                    .Where(a => !string.IsNullOrEmpty(a.Category) && !a.IsDeleted)
                    .Select(a => a.Category!)
                    .Distinct()
                    .OrderBy(c => c)
                    .ToListAsync();
            }
            
            return Ok(categories);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách categories", message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    [Authorize]
    public async Task<ActionResult<Amenity>> Get(Guid id)
        => await _db.Amenities.FindAsync(id) is { } m ? m : NotFound();

    [HttpPost]
    [Authorize(Roles = "Manager")]
    public async Task<ActionResult<Amenity>> Create(Amenity m)
    {
        _db.Amenities.Add(m); await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = m.Id }, m);
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Update(Guid id, Amenity m)
    {
        var dbm = await _db.Amenities.FindAsync(id);
        if (dbm is null) return NotFound();
        dbm.Name = m.Name; dbm.Description = m.Description; dbm.AllowBooking = m.AllowBooking; dbm.PricePerHour = m.PricePerHour;
        dbm.Category = m.Category; dbm.ImageUrl = m.ImageUrl; dbm.Location = m.Location;
        dbm.OpenHourStart = m.OpenHourStart; dbm.OpenHourEnd = m.OpenHourEnd; dbm.UsageRules = m.UsageRules;
        dbm.MinDurationMinutes = m.MinDurationMinutes; dbm.MaxDurationMinutes = m.MaxDurationMinutes; dbm.MaxAdvanceDays = m.MaxAdvanceDays;
        dbm.RequireManualApproval = m.RequireManualApproval; dbm.MaxPerDay = m.MaxPerDay; dbm.MaxPerWeek = m.MaxPerWeek;
        dbm.RequirePrepayment = m.RequirePrepayment;
        await _db.SaveChangesAsync(); return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var m = await _db.Amenities.FindAsync(id);
        if (m is null) return NotFound();
        _db.Amenities.Remove(m); await _db.SaveChangesAsync(); return NoContent();
    }

    /// <summary>
    /// Upload hình ảnh cho tiện ích
    /// POST /api/Amenities/upload-image
    /// </summary>
    [HttpPost("upload-image")]
    [Authorize(Roles = "Manager")]
    [ApiExplorerSettings(IgnoreApi = true)]  // Temporarily hide from Swagger
    public async Task<IActionResult> UploadImage(IFormFile file)
    {
        try
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { error = "No file uploaded" });

            // Validate file type
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            
            if (!allowedExtensions.Contains(extension))
                return BadRequest(new { error = "Invalid file type. Only images are allowed." });

            // Validate file size (max 5MB)
            if (file.Length > 5 * 1024 * 1024)
                return BadRequest(new { error = "File size exceeds 5MB limit" });

            // Generate unique filename
            var fileName = $"amenity_{Guid.NewGuid()}{extension}";
            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "amenities");
            
            // Ensure directory exists
            if (!Directory.Exists(uploadsFolder))
                Directory.CreateDirectory(uploadsFolder);

            var filePath = Path.Combine(uploadsFolder, fileName);

            // Save file
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            // Return URL
            var fileUrl = $"/images/amenities/{fileName}";
            return Ok(new { url = fileUrl, fileName = fileName });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Upload failed", message = ex.Message });
        }
    }
}
