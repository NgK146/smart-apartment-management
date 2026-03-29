using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace ICitizenAPI.Controllers
{
    /// <summary>
    /// API Controller cho Categories
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class CategoriesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public CategoriesController(ApplicationDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Lấy danh sách tất cả categories đang active
        /// GET /api/Categories
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<CategoryDto>>> GetCategories()
        {
            var categories = await _context.Categories
                .Where(c => c.IsActive)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => new CategoryDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    Description = c.Description,
                    Icon = c.Icon
                })
                .ToListAsync();

            return Ok(categories);
        }

        /// <summary>
        /// Lấy danh sách tên categories (chỉ tên, dùng cho dropdown)
        /// GET /api/Categories/names
        /// </summary>
        [HttpGet("names")]
        public async Task<ActionResult<List<string>>> GetCategoryNames()
        {
            var names = await _context.Categories
                .Where(c => c.IsActive)
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => c.Name)
                .ToListAsync();

            return Ok(names);
        }

        /// <summary>
        /// Lấy category theo ID
        /// GET /api/Categories/{id}
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<CategoryDto>> GetCategory(int id)
        {
            var category = await _context.Categories
                .Where(c => c.Id == id && c.IsActive)
                .Select(c => new CategoryDto
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

        /// <summary>
        /// Tạo category mới (Admin only)
        /// POST /api/Categories
        /// </summary>
        [HttpPost]
        [Authorize(Roles = "Manager,Admin")]
        public async Task<ActionResult<CategoryDto>> CreateCategory([FromBody] CreateCategoryDto dto)
        {
            // Kiểm tra category đã tồn tại chưa
            var exists = await _context.Categories
                .AnyAsync(c => c.Name == dto.Name);

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
                DisplayOrder = dto.DisplayOrder ?? 0,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Categories.Add(category);
            await _context.SaveChangesAsync();

            return Ok(new CategoryDto
            {
                Id = category.Id,
                Name = category.Name,
                Description = category.Description,
                Icon = category.Icon
            });
        }

        /// <summary>
        /// Cập nhật category (Admin only)
        /// PUT /api/Categories/{id}
        /// </summary>
        [HttpPut("{id}")]
        [Authorize(Roles = "Manager,Admin")]
        public async Task<IActionResult> UpdateCategory(int id, [FromBody] UpdateCategoryDto dto)
        {
            var category = await _context.Categories.FindAsync(id);
            if (category == null)
            {
                return NotFound();
            }

            // Kiểm tra tên mới có trùng với category khác không
            if (dto.Name != category.Name)
            {
                var exists = await _context.Categories
                    .AnyAsync(c => c.Name == dto.Name && c.Id != id);
                if (exists)
                {
                    return BadRequest(new { error = "Category đã tồn tại" });
                }
            }

            category.Name = dto.Name;
            category.Description = dto.Description;
            category.Icon = dto.Icon;
            category.DisplayOrder = dto.DisplayOrder ?? category.DisplayOrder;
            category.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return NoContent();
        }

        /// <summary>
        /// Xóa category (soft delete - Admin only)
        /// DELETE /api/Categories/{id}
        /// </summary>
        [HttpDelete("{id}")]
        [Authorize(Roles = "Manager,Admin")]
        public async Task<IActionResult> DeleteCategory(int id)
        {
            var category = await _context.Categories.FindAsync(id);
            if (category == null)
            {
                return NotFound();
            }

            // Soft delete
            category.IsActive = false;
            category.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return NoContent();
        }
    }

    // ============================================
    // DTOs
    // ============================================

    public class CategoryDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string Icon { get; set; }
    }

    public class CreateCategoryDto
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public string Icon { get; set; }
        public int? DisplayOrder { get; set; }
    }

    public class UpdateCategoryDto
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public string Icon { get; set; }
        public int? DisplayOrder { get; set; }
    }

    // ============================================
    // Model
    // ============================================

    public class Category
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string Icon { get; set; }
        public bool IsActive { get; set; }
        public int DisplayOrder { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}

