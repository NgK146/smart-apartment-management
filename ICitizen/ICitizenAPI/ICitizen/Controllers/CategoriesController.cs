using ICitizen.Common;
using ICitizen.Data;
using ICitizen.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly ApplicationDbContext _db;

    public CategoriesController(ApplicationDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Lấy danh sách tất cả categories đang active
    /// GET /api/Categories
    /// </summary>
    [HttpGet]
    [Authorize]
    public async Task<ActionResult<List<AmenityCategoryDto>>> GetCategories()
    {
        try
        {
            var categories = await _db.Categories
                .Where(c => c.IsActive && !c.IsDeleted)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => new AmenityCategoryDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    Description = c.Description,
                    Icon = c.Icon
                })
                .ToListAsync();

            return Ok(categories);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách categories", message = ex.Message });
        }
    }

    /// <summary>
    /// Lấy danh sách tên categories (chỉ tên, dùng cho dropdown)
    /// GET /api/Categories/names
    /// </summary>
    [HttpGet("names")]
    [Authorize]
    public async Task<ActionResult<List<string>>> GetCategoryNames()
    {
        try
        {
            var names = await _db.Categories
                .Where(c => c.IsActive && !c.IsDeleted)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => c.Name)
                .ToListAsync();

            return Ok(names);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải danh sách categories", message = ex.Message });
        }
    }

    /// <summary>
    /// Lấy category theo ID
    /// GET /api/Categories/{id}
    /// </summary>
    [HttpGet("{id}")]
    [Authorize]
    public async Task<ActionResult<AmenityCategoryDto>> GetCategory(Guid id)
    {
        try
        {
            var category = await _db.Categories
                .Where(c => c.Id == id && c.IsActive && !c.IsDeleted)
                .Select(c => new AmenityCategoryDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    Description = c.Description,
                    Icon = c.Icon
                })
                .FirstOrDefaultAsync();

            if (category == null)
            {
                return NotFound();
            }

            return Ok(category);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tải category", message = ex.Message });
        }
    }

    /// <summary>
    /// Tạo category mới (Admin only)
    /// POST /api/Categories
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Manager,Admin")]
    public async Task<ActionResult<AmenityCategoryDto>> CreateCategory([FromBody] CreateAmenityCategoryDto dto)
    {
        try
        {
            // Kiểm tra category đã tồn tại chưa
            var exists = await _db.Categories
                .AnyAsync(c => c.Name == dto.Name && !c.IsDeleted);

            if (exists)
            {
                return BadRequest(new { error = "Category đã tồn tại" });
            }

            var category = new Category
            {
                Name = dto.Name,
                Description = dto.Description,
                Icon = dto.Icon,
                IsActive = true,
                DisplayOrder = dto.DisplayOrder ?? 0
            };

            _db.Categories.Add(category);
            await _db.SaveChangesAsync();

            return Ok(new AmenityCategoryDto
            {
                Id = category.Id,
                Name = category.Name,
                Description = category.Description,
                Icon = category.Icon
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi tạo category", message = ex.Message });
        }
    }

    /// <summary>
    /// Cập nhật category (Admin only)
    /// PUT /api/Categories/{id}
    /// </summary>
    [HttpPut("{id}")]
    [Authorize(Roles = "Manager,Admin")]
    public async Task<IActionResult> UpdateCategory(Guid id, [FromBody] UpdateAmenityCategoryDto dto)
    {
        try
        {
            var category = await _db.Categories.FindAsync(id);
            if (category == null || category.IsDeleted)
            {
                return NotFound();
            }

            // Kiểm tra tên mới có trùng với category khác không
            if (dto.Name != category.Name)
            {
                var exists = await _db.Categories
                    .AnyAsync(c => c.Name == dto.Name && c.Id != id && !c.IsDeleted);
                if (exists)
                {
                    return BadRequest(new { error = "Category đã tồn tại" });
                }
            }

            category.Name = dto.Name;
            category.Description = dto.Description;
            category.Icon = dto.Icon;
            category.DisplayOrder = dto.DisplayOrder ?? category.DisplayOrder;

            await _db.SaveChangesAsync();

            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi cập nhật category", message = ex.Message });
        }
    }

    /// <summary>
    /// Xóa category (soft delete - Admin only)
    /// DELETE /api/Categories/{id}
    /// </summary>
    [HttpDelete("{id}")]
    [Authorize(Roles = "Manager,Admin")]
    public async Task<IActionResult> DeleteCategory(Guid id)
    {
        try
        {
            var category = await _db.Categories.FindAsync(id);
            if (category == null || category.IsDeleted)
            {
                return NotFound();
            }

            // Soft delete
            category.IsDeleted = true;
            category.IsActive = false;

            await _db.SaveChangesAsync();

            return NoContent();
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Lỗi khi xóa category", message = ex.Message });
        }
    }
}

// ============================================
// DTOs
// ============================================

public class AmenityCategoryDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Icon { get; set; }
}

public class CreateAmenityCategoryDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public int? DisplayOrder { get; set; }
}

public class UpdateAmenityCategoryDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public int? DisplayOrder { get; set; }
}

