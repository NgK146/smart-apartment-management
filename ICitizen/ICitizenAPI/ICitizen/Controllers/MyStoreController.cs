using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ICitizen.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public sealed class MyStoreController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public MyStoreController(ApplicationDbContext db, UserManager<AppUser> um)
        {
            _db = db;
            _userManager = um;
        }

        // GET /api/my-store - Lấy thông tin Store của mình (yêu cầu role Seller hoặc đã có cửa hàng)
        [HttpGet]
        public async Task<IActionResult> GetMyStore()
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .Where(s => !s.IsDeleted && s.OwnerId == me.Id)
                .Select(s => new
                {
                    s.Id,
                    s.Name,
                    s.Description,
                    s.Phone,
                    s.LogoUrl,
                    s.CoverImageUrl,
                    s.IsApproved,
                    s.IsActive,
                    s.OwnerId,
                    AverageRating = s.Reviews.Any() ? s.Reviews.Average(r => (double?)r.Rating) : null,
                    TotalReviews = s.Reviews.Count
                })
                .FirstOrDefaultAsync();

            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            return Ok(store);
        }

        // PUT /api/my-store - Cập nhật Store (yêu cầu role Seller)
        [HttpPut]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> UpdateStore([FromBody] UpdateStoreDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            if (!string.IsNullOrWhiteSpace(dto.Name)) store.Name = dto.Name;
            if (dto.Description != null) store.Description = dto.Description;
            if (dto.Phone != null) store.Phone = dto.Phone;
            if (dto.LogoUrl != null) store.LogoUrl = dto.LogoUrl;
            if (dto.CoverImageUrl != null) store.CoverImageUrl = dto.CoverImageUrl;

            await _db.SaveChangesAsync();

            return Ok(new
            {
                store.Id,
                store.Name,
                store.Description,
                store.Phone,
                store.LogoUrl,
                store.CoverImageUrl,
                store.IsApproved,
                store.IsActive,
                store.OwnerId
            });
        }

        // POST /api/my-store/register - Đăng ký trở thành người bán (không cần role Seller)
        [HttpPost("register")]
        public async Task<IActionResult> RegisterStore([FromBody] RegisterStoreDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            // Kiểm tra đã có cửa hàng chưa
            var existingStore = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (existingStore != null) return BadRequest("Bạn đã có cửa hàng rồi");

            var store = new Store
            {
                Name = dto.Name,
                Phone = dto.Phone,
                Description = dto.Description,
                OwnerId = me.Id,
                IsApproved = false, // Chờ BQL duyệt
                IsActive = true
            };

            _db.Stores.Add(store);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                store.Id,
                store.Name,
                store.Description,
                store.Phone,
                store.IsApproved,
                store.IsActive,
                store.OwnerId
            });
        }

        // === QUẢN LÝ DANH MỤC ===

        // GET /api/my-store/categories (yêu cầu role Seller)
        [HttpGet("categories")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> GetCategories()
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var categories = await _db.ProductCategories
                .Where(c => !c.IsDeleted && c.StoreId == store.Id)
                .Select(c => new
                {
                    c.Id,
                    c.Name,
                    c.StoreId
                })
                .ToListAsync();

            return Ok(categories);
        }

        // POST /api/my-store/categories (yêu cầu role Seller)
        [HttpPost("categories")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> CreateCategory([FromBody] CreateCategoryDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var category = new ProductCategory
            {
                Name = dto.Name,
                StoreId = store.Id
            };

            _db.ProductCategories.Add(category);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                category.Id,
                category.Name,
                category.StoreId
            });
        }

        // PUT /api/my-store/categories/{id} (yêu cầu role Seller)
        [HttpPut("categories/{id}")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> UpdateCategory(Guid id, [FromBody] UpdateCategoryDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var category = await _db.ProductCategories
                .FirstOrDefaultAsync(c => !c.IsDeleted && c.Id == id && c.StoreId == store.Id);
            if (category == null) return NotFound();

            category.Name = dto.Name;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                category.Id,
                category.Name,
                category.StoreId
            });
        }

        // DELETE /api/my-store/categories/{id} (yêu cầu role Seller)
        [HttpDelete("categories/{id}")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> DeleteCategory(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var category = await _db.ProductCategories
                .FirstOrDefaultAsync(c => !c.IsDeleted && c.Id == id && c.StoreId == store.Id);
            if (category == null) return NotFound();

            // Kiểm tra có sản phẩm đang dùng danh mục này không
            var hasProducts = await _db.Products
                .AnyAsync(p => !p.IsDeleted && p.ProductCategoryId == id);
            if (hasProducts) return BadRequest("Không thể xóa danh mục đang có sản phẩm");

            category.IsDeleted = true;
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa danh mục" });
        }

        // === QUẢN LÝ SẢN PHẨM ===

        // GET /api/my-store/products (yêu cầu role Seller)
        [HttpGet("products")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> GetProducts([FromQuery] string? search, [FromQuery] Guid? categoryId)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var query = _db.Products
                .Where(p => !p.IsDeleted && p.StoreId == store.Id)
                .AsQueryable();

            if (categoryId.HasValue)
            {
                query = query.Where(p => p.ProductCategoryId == categoryId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(p =>
                    p.Name.ToLower().Contains(searchLower) ||
                    (p.Description != null && p.Description.ToLower().Contains(searchLower)));
            }

            var products = await query
                .Include(p => p.ProductCategory)
                .Select(p => new
                {
                    p.Id,
                    p.Name,
                    p.Description,
                    p.Price,
                    p.ImageUrl,
                    p.Type,
                    p.IsAvailable,
                    p.StoreId,
                    p.ProductCategoryId,
                    CategoryName = p.ProductCategory != null ? p.ProductCategory.Name : null
                })
                .ToListAsync();

            return Ok(products);
        }

        // POST /api/my-store/products (yêu cầu role Seller)
        [HttpPost("products")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> CreateProduct([FromBody] CreateProductDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            // Kiểm tra danh mục
            var category = await _db.ProductCategories
                .FirstOrDefaultAsync(c => !c.IsDeleted && c.Id == dto.ProductCategoryId && c.StoreId == store.Id);
            if (category == null) return BadRequest("Danh mục không tồn tại");

            var product = new Product
            {
                Name = dto.Name,
                Description = dto.Description,
                Price = dto.Price,
                ImageUrl = dto.ImageUrl,
                Type = dto.Type,
                IsAvailable = dto.IsAvailable,
                StoreId = store.Id,
                ProductCategoryId = dto.ProductCategoryId
            };

            _db.Products.Add(product);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                product.Id,
                product.Name,
                product.Description,
                product.Price,
                product.ImageUrl,
                product.Type,
                product.IsAvailable,
                product.StoreId,
                product.ProductCategoryId
            });
        }

        // PUT /api/my-store/products/{id} (yêu cầu role Seller)
        [HttpPut("products/{id}")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> UpdateProduct(Guid id, [FromBody] UpdateProductDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var product = await _db.Products
                .FirstOrDefaultAsync(p => !p.IsDeleted && p.Id == id && p.StoreId == store.Id);
            if (product == null) return NotFound();

            if (!string.IsNullOrWhiteSpace(dto.Name)) product.Name = dto.Name;
            if (dto.Description != null) product.Description = dto.Description;
            if (dto.Price.HasValue) product.Price = dto.Price.Value;
            if (dto.ImageUrl != null) product.ImageUrl = dto.ImageUrl;
            if (dto.Type.HasValue) product.Type = dto.Type.Value;
            if (dto.IsAvailable.HasValue) product.IsAvailable = dto.IsAvailable.Value;
            if (dto.ProductCategoryId.HasValue)
            {
                var category = await _db.ProductCategories
                    .FirstOrDefaultAsync(c => !c.IsDeleted && c.Id == dto.ProductCategoryId.Value && c.StoreId == store.Id);
                if (category == null) return BadRequest("Danh mục không tồn tại");
                product.ProductCategoryId = dto.ProductCategoryId.Value;
            }

            await _db.SaveChangesAsync();

            return Ok(new
            {
                product.Id,
                product.Name,
                product.Description,
                product.Price,
                product.ImageUrl,
                product.Type,
                product.IsAvailable,
                product.StoreId,
                product.ProductCategoryId
            });
        }

        // DELETE /api/my-store/products/{id} (yêu cầu role Seller)
        [HttpDelete("products/{id}")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> DeleteProduct(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var product = await _db.Products
                .FirstOrDefaultAsync(p => !p.IsDeleted && p.Id == id && p.StoreId == store.Id);
            if (product == null) return NotFound();

            product.IsDeleted = true;
            await _db.SaveChangesAsync();

            return Ok(new { message = "Đã xóa sản phẩm" });
        }

        // === QUẢN LÝ ĐƠN HÀNG ===

        // GET /api/my-store/orders (yêu cầu role Seller)
        [HttpGet("orders")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> GetOrders([FromQuery] string? status)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var query = _db.Orders
                .Where(o => !o.IsDeleted && o.StoreId == store.Id)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<OrderStatus>(status, true, out var orderStatus))
            {
                query = query.Where(o => o.Status == orderStatus);
            }

            var orders = await query
                .Include(o => o.Buyer)
                .Select(o => new
                {
                    o.Id,
                    o.TotalAmount,
                    o.Status,
                    o.Notes,
                    o.BuyerId,
                    o.StoreId,
                    BuyerName = o.Buyer != null ? o.Buyer.FullName : null,
                    o.CreatedAtUtc
                })
                .OrderByDescending(o => o.CreatedAtUtc)
                .ToListAsync();

            return Ok(orders);
        }

        // PUT /api/my-store/orders/{id}/confirm - Xác nhận đơn (yêu cầu role Seller)
        [HttpPut("orders/{id}/confirm")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> ConfirmOrder(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var order = await _db.Orders
                .FirstOrDefaultAsync(o => !o.IsDeleted && o.Id == id && o.StoreId == store.Id);
            if (order == null) return NotFound();

            if (order.Status != OrderStatus.Pending)
                return BadRequest("Chỉ có thể xác nhận đơn hàng đang chờ xác nhận");

            order.Status = OrderStatus.Confirmed;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                order.Id,
                order.TotalAmount,
                order.Status,
                order.Notes,
                order.BuyerId,
                order.StoreId,
                order.CreatedAtUtc
            });
        }

        // PUT /api/my-store/orders/{id}/complete - Hoàn thành đơn (yêu cầu role Seller)
        [HttpPut("orders/{id}/complete")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> CompleteOrder(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var order = await _db.Orders
                .FirstOrDefaultAsync(o => !o.IsDeleted && o.Id == id && o.StoreId == store.Id);
            if (order == null) return NotFound();

            if (order.Status != OrderStatus.Delivering)
                return BadRequest("Chỉ có thể hoàn thành đơn hàng đang giao");

            order.Status = OrderStatus.Completed;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                order.Id,
                order.TotalAmount,
                order.Status,
                order.Notes,
                order.BuyerId,
                order.StoreId,
                order.CreatedAtUtc
            });
        }

        // PUT /api/my-store/orders/{id}/cancel - Hủy đơn (yêu cầu role Seller)
        [HttpPut("orders/{id}/cancel")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> CancelOrder(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var order = await _db.Orders
                .FirstOrDefaultAsync(o => !o.IsDeleted && o.Id == id && o.StoreId == store.Id);
            if (order == null) return NotFound();

            if (order.Status == OrderStatus.Completed || order.Status == OrderStatus.Cancelled)
                return BadRequest("Không thể hủy đơn hàng đã hoàn thành hoặc đã hủy");

            order.Status = OrderStatus.Cancelled;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                order.Id,
                order.TotalAmount,
                order.Status,
                order.Notes,
                order.BuyerId,
                order.StoreId,
                order.CreatedAtUtc
            });
        }

        // === ĐÁNH GIÁ & THỐNG KÊ ===

        // GET /api/my-store/reviews (yêu cầu role Seller)
        [HttpGet("reviews")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> GetReviews()
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var reviews = await _db.StoreReviews
                .Where(r => !r.IsDeleted && r.StoreId == store.Id)
                .Include(r => r.Resident)
                .Select(r => new
                {
                    r.Id,
                    r.Rating,
                    r.Comment,
                    r.CreatedAtUtc,
                    r.StoreId,
                    r.ResidentId,
                    ResidentName = r.Resident != null ? r.Resident.FullName : null,
                    r.OrderId
                })
                .OrderByDescending(r => r.CreatedAtUtc)
                .ToListAsync();

            return Ok(reviews);
        }

        // GET /api/my-store/statistics (yêu cầu role Seller)
        [HttpGet("statistics")]
        [Authorize(Roles = "Seller")]
        public async Task<IActionResult> GetStatistics()
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.OwnerId == me.Id);
            if (store == null) return NotFound("Bạn chưa có cửa hàng");

            var now = DateTime.UtcNow;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);

            var pendingOrders = await _db.Orders
                .CountAsync(o => !o.IsDeleted && o.StoreId == store.Id && o.Status == OrderStatus.Pending);

            var monthlyRevenue = await _db.Orders
                .Where(o => !o.IsDeleted && o.StoreId == store.Id &&
                    o.Status == OrderStatus.Completed &&
                    o.CreatedAtUtc >= startOfMonth)
                .SumAsync(o => (decimal?)o.TotalAmount) ?? 0;

            var totalProducts = await _db.Products
                .CountAsync(p => !p.IsDeleted && p.StoreId == store.Id);

            var averageRating = await _db.StoreReviews
                .Where(r => !r.IsDeleted && r.StoreId == store.Id)
                .AverageAsync(r => (double?)r.Rating) ?? 0;

            return Ok(new
            {
                PendingOrders = pendingOrders,
                MonthlyRevenue = monthlyRevenue,
                TotalProducts = totalProducts,
                AverageRating = averageRating
            });
        }
    }

    // DTOs
    public class RegisterStoreDto
    {
        public string Name { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string? Description { get; set; }
    }

    public class UpdateStoreDto
    {
        public string? Name { get; set; }
        public string? Description { get; set; }
        public string? Phone { get; set; }
        public string? LogoUrl { get; set; }
        public string? CoverImageUrl { get; set; }
    }

    public class CreateCategoryDto
    {
        public string Name { get; set; } = string.Empty;
    }

    public class UpdateCategoryDto
    {
        public string Name { get; set; } = string.Empty;
    }

    public class CreateProductDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public decimal Price { get; set; }
        public string? ImageUrl { get; set; }
        public ProductType Type { get; set; } = ProductType.Physical;
        public bool IsAvailable { get; set; } = true;
        public Guid ProductCategoryId { get; set; }
    }

    public class UpdateProductDto
    {
        public string? Name { get; set; }
        public string? Description { get; set; }
        public decimal? Price { get; set; }
        public string? ImageUrl { get; set; }
        public ProductType? Type { get; set; }
        public bool? IsAvailable { get; set; }
        public Guid? ProductCategoryId { get; set; }
    }
}

