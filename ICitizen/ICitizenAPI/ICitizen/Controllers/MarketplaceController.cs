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
    public sealed class MarketplaceController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public MarketplaceController(ApplicationDbContext db, UserManager<AppUser> um)
        {
            _db = db;
            _userManager = um;
        }

        // GET /api/marketplace/stores - Lấy danh sách tất cả Store đã được duyệt
        [HttpGet("stores")]
        public async Task<IActionResult> GetStores([FromQuery] string? search)
        {
            var query = _db.Stores
                .Where(s => !s.IsDeleted && s.IsApproved && s.IsActive)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(s =>
                    s.Name.ToLower().Contains(searchLower) ||
                    (s.Description != null && s.Description.ToLower().Contains(searchLower)));
            }

            var stores = await query
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
                .OrderByDescending(s => s.AverageRating ?? 0)
                .ToListAsync();

            return Ok(stores);
        }

        // GET /api/marketplace/stores/{id} - Lấy "Trang Cửa hàng" công khai
        [HttpGet("stores/{id}")]
        public async Task<IActionResult> GetStore(Guid id)
        {
            var store = await _db.Stores
                .Where(s => !s.IsDeleted && s.IsApproved && s.IsActive && s.Id == id)
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

            if (store == null) return NotFound();

            return Ok(store);
        }

        // GET /api/marketplace/stores/{id}/products - Lấy danh sách sản phẩm của cửa hàng
        [HttpGet("stores/{id}/products")]
        public async Task<IActionResult> GetStoreProducts(Guid id, [FromQuery] Guid? categoryId)
        {
            var query = _db.Products
                .Where(p => !p.IsDeleted && p.StoreId == id && p.IsAvailable)
                .AsQueryable();

            if (categoryId.HasValue)
            {
                query = query.Where(p => p.ProductCategoryId == categoryId.Value);
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

        // GET /api/marketplace/products/{id} - Xem chi tiết 1 sản phẩm
        [HttpGet("products/{id}")]
        public async Task<IActionResult> GetProduct(Guid id)
        {
            var product = await _db.Products
                .Where(p => !p.IsDeleted && p.Id == id)
                .Include(p => p.Store)
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
                    StoreName = p.Store != null ? p.Store.Name : null,
                    p.ProductCategoryId,
                    CategoryName = p.ProductCategory != null ? p.ProductCategory.Name : null
                })
                .FirstOrDefaultAsync();

            if (product == null) return NotFound();

            return Ok(product);
        }

        // GET /api/marketplace/products - Tìm kiếm sản phẩm
        [HttpGet("products")]
        public async Task<IActionResult> SearchProducts([FromQuery] string? search, [FromQuery] Guid? storeId)
        {
            var query = _db.Products
                .Where(p => !p.IsDeleted && p.IsAvailable)
                .Include(p => p.Store)
                .Where(p => p.Store != null && !p.Store.IsDeleted && p.Store.IsApproved && p.Store.IsActive)
                .AsQueryable();

            if (storeId.HasValue)
            {
                query = query.Where(p => p.StoreId == storeId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(p =>
                    p.Name.ToLower().Contains(searchLower) ||
                    (p.Description != null && p.Description.ToLower().Contains(searchLower)));
            }

            var products = await query
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
                    StoreName = p.Store != null ? p.Store.Name : null,
                    p.ProductCategoryId,
                    CategoryName = p.ProductCategory != null ? p.ProductCategory.Name : null
                })
                .ToListAsync();

            return Ok(products);
        }

        // GET /api/marketplace/my-orders - Xem lịch sử đơn hàng mình đã mua
        [HttpGet("my-orders")]
        public async Task<IActionResult> GetMyOrders()
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var orders = await _db.Orders
                .Where(o => !o.IsDeleted && o.BuyerId == me.Id)
                .Include(o => o.Store)
                .Include(o => o.Buyer)
                .Select(o => new
                {
                    o.Id,
                    o.TotalAmount,
                    o.Status,
                    o.Notes,
                    o.BuyerId,
                    o.StoreId,
                    StoreName = o.Store != null ? o.Store.Name : null,
                    BuyerName = o.Buyer != null ? o.Buyer.FullName : null,
                    o.CreatedAtUtc
                })
                .OrderByDescending(o => o.CreatedAtUtc)
                .ToListAsync();

            return Ok(orders);
        }

        // GET /api/marketplace/orders/{id} - Xem chi tiết đơn hàng
        [HttpGet("orders/{id}")]
        public async Task<IActionResult> GetOrder(Guid id)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            var order = await _db.Orders
                .Where(o => !o.IsDeleted && o.Id == id && o.BuyerId == me.Id)
                .Include(o => o.Store)
                .Include(o => o.Buyer)
                .Include(o => o.OrderDetails)
                    .ThenInclude(od => od.Product)
                .Select(o => new
                {
                    o.Id,
                    o.TotalAmount,
                    o.Status,
                    o.Notes,
                    o.BuyerId,
                    o.StoreId,
                    StoreName = o.Store != null ? o.Store.Name : null,
                    BuyerName = o.Buyer != null ? o.Buyer.FullName : null,
                    o.CreatedAtUtc,
                    OrderDetails = o.OrderDetails.Select(od => new
                    {
                        od.Id,
                        od.Quantity,
                        od.PriceAtPurchase,
                        od.OrderId,
                        od.ProductId,
                        Product = od.Product != null ? new
                        {
                            od.Product.Id,
                            od.Product.Name,
                            od.Product.Description,
                            od.Product.Price,
                            od.Product.ImageUrl,
                            od.Product.Type,
                            od.Product.IsAvailable
                        } : null
                    }).ToList()
                })
                .FirstOrDefaultAsync();

            if (order == null) return NotFound();

            return Ok(order);
        }

        // POST /api/marketplace/orders - Tạo đơn hàng mới
        [HttpPost("orders")]
        public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            // Kiểm tra cửa hàng
            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.Id == dto.StoreId && s.IsApproved && s.IsActive);
            if (store == null) return BadRequest("Cửa hàng không tồn tại hoặc không hoạt động");

            // Kiểm tra sản phẩm
            var productIds = dto.Items.Select(i => i.ProductId).ToList();
            var products = await _db.Products
                .Where(p => !p.IsDeleted && productIds.Contains(p.Id) && p.StoreId == dto.StoreId && p.IsAvailable)
                .ToListAsync();

            if (products.Count != dto.Items.Count)
                return BadRequest("Một số sản phẩm không tồn tại hoặc không còn hàng");

            // Tính tổng tiền
            decimal totalAmount = 0;
            var orderDetails = new List<OrderDetail>();

            foreach (var item in dto.Items)
            {
                var product = products.First(p => p.Id == item.ProductId);
                var detail = new OrderDetail
                {
                    ProductId = product.Id,
                    Quantity = item.Quantity,
                    PriceAtPurchase = product.Price
                };
                totalAmount += product.Price * item.Quantity;
                orderDetails.Add(detail);
            }

            // Tạo đơn hàng
            var order = new Order
            {
                BuyerId = me.Id,
                StoreId = dto.StoreId,
                TotalAmount = totalAmount,
                Status = OrderStatus.Pending,
                Notes = dto.Notes
            };

            _db.Orders.Add(order);
            await _db.SaveChangesAsync();

            // Thêm chi tiết đơn hàng
            foreach (var detail in orderDetails)
            {
                detail.OrderId = order.Id;
                _db.OrderDetails.Add(detail);
            }

            await _db.SaveChangesAsync();

            // Load lại với relations
            await _db.Entry(order).Reference(o => o.Store).LoadAsync();
            await _db.Entry(order).Reference(o => o.Buyer).LoadAsync();
            await _db.Entry(order).Collection(o => o.OrderDetails).LoadAsync();

            return Ok(new
            {
                order.Id,
                order.TotalAmount,
                order.Status,
                order.Notes,
                order.BuyerId,
                order.StoreId,
                StoreName = order.Store?.Name,
                BuyerName = order.Buyer?.FullName,
                order.CreatedAtUtc
            });
        }

        // GET /api/marketplace/stores/{id}/reviews - Lấy đánh giá của cửa hàng
        [HttpGet("stores/{id}/reviews")]
        public async Task<IActionResult> GetStoreReviews(Guid id)
        {
            var reviews = await _db.StoreReviews
                .Where(r => !r.IsDeleted && r.StoreId == id)
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

        // POST /api/marketplace/reviews - Gửi đánh giá cho Store
        [HttpPost("reviews")]
        public async Task<IActionResult> CreateReview([FromBody] CreateReviewDto dto)
        {
            var me = await _userManager.GetUserAsync(User);
            if (me == null) return Unauthorized();

            // Kiểm tra cửa hàng
            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.Id == dto.StoreId && s.IsApproved);
            if (store == null) return BadRequest("Cửa hàng không tồn tại");

            // Kiểm tra đã mua hàng chưa (nếu có orderId)
            if (dto.OrderId.HasValue)
            {
                var order = await _db.Orders
                    .FirstOrDefaultAsync(o => !o.IsDeleted && o.Id == dto.OrderId.Value &&
                        o.BuyerId == me.Id && o.StoreId == dto.StoreId);
                if (order == null) return BadRequest("Bạn chưa mua hàng từ cửa hàng này");
            }

            var review = new StoreReview
            {
                StoreId = dto.StoreId,
                ResidentId = me.Id,
                Rating = dto.Rating,
                Comment = dto.Comment,
                OrderId = dto.OrderId
            };

            _db.StoreReviews.Add(review);
            await _db.SaveChangesAsync();

            await _db.Entry(review).Reference(r => r.Resident).LoadAsync();

            return Ok(new
            {
                review.Id,
                review.Rating,
                review.Comment,
                review.CreatedAtUtc,
                review.StoreId,
                review.ResidentId,
                ResidentName = review.Resident?.FullName,
                review.OrderId
            });
        }
    }

    // DTOs
    public class CreateOrderDto
    {
        public Guid StoreId { get; set; }
        public List<OrderItemDto> Items { get; set; } = new();
        public string? Notes { get; set; }
    }

    public class OrderItemDto
    {
        public Guid ProductId { get; set; }
        public int Quantity { get; set; }
    }

    public class CreateReviewDto
    {
        public Guid StoreId { get; set; }
        public int Rating { get; set; }
        public string? Comment { get; set; }
        public Guid? OrderId { get; set; }
    }
}

