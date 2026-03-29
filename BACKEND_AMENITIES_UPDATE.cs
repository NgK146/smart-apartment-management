// ============================================
// Cập nhật AmenitiesController để hỗ trợ filter theo category
// ============================================

// Thêm vào class QueryParameters (hoặc tạo mới nếu chưa có)
public class QueryParameters
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 50;
    public string? Search { get; set; }
    public string? Category { get; set; } // Thêm field này
}

// Cập nhật method List trong AmenitiesController
[HttpGet]
[Authorize]
public async Task<IActionResult> List([FromQuery] QueryParameters p)
{
    try
    {
        var query = _db.Amenities.AsQueryable();
        
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

// Thêm endpoint để lấy categories (nếu chưa có CategoriesController)
[HttpGet("categories")]
[Authorize]
public async Task<IActionResult> GetCategories()
{
    try
    {
        // Lấy danh sách categories từ bảng Categories (nếu có)
        var categories = await _db.Categories
            .Where(c => c.IsActive)
            .OrderBy(c => c.DisplayOrder)
            .ThenBy(c => c.Name)
            .Select(c => c.Name)
            .ToListAsync();
            
        // Nếu chưa có bảng Categories, lấy từ Amenities
        if (!categories.Any())
        {
            categories = await _db.Amenities
                .Where(a => !string.IsNullOrEmpty(a.Category))
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

