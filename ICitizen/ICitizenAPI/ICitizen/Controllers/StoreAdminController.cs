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
    [Route("api/admin")]
    [Authorize(Roles = "Manager")]
    public sealed class StoreAdminController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public StoreAdminController(ApplicationDbContext db, UserManager<AppUser> um)
        {
            _db = db;
            _userManager = um;
        }

        // GET /api/admin/stores/pending - Lấy danh sách các Store chờ duyệt
        [HttpGet("stores/pending")]
        public async Task<IActionResult> GetPendingStores()
        {
            var stores = await _db.Stores
                .Where(s => !s.IsDeleted && !s.IsApproved)
                .Include(s => s.Owner)
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
                    OwnerName = s.Owner != null ? s.Owner.FullName : null,
                    OwnerEmail = s.Owner != null ? s.Owner.Email : null,
                    s.CreatedAtUtc
                })
                .OrderBy(s => s.CreatedAtUtc)
                .ToListAsync();

            return Ok(stores);
        }

        // GET /api/admin/stores - Lấy danh sách tất cả cửa hàng
        [HttpGet("stores")]
        public async Task<IActionResult> GetAllStores([FromQuery] string? search, [FromQuery] bool? isActive)
        {
            var query = _db.Stores
                .Where(s => !s.IsDeleted)
                .AsQueryable();

            if (isActive.HasValue)
            {
                query = query.Where(s => s.IsActive == isActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(s =>
                    s.Name.ToLower().Contains(searchLower) ||
                    (s.Description != null && s.Description.ToLower().Contains(searchLower)) ||
                    (s.Phone != null && s.Phone.Contains(search)));
            }

            var stores = await query
                .Include(s => s.Owner)
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
                    OwnerName = s.Owner != null ? s.Owner.FullName : null,
                    OwnerEmail = s.Owner != null ? s.Owner.Email : null,
                    AverageRating = s.Reviews.Any() ? s.Reviews.Average(r => (double?)r.Rating) : null,
                    TotalReviews = s.Reviews.Count,
                    s.CreatedAtUtc
                })
                .OrderByDescending(s => s.CreatedAtUtc)
                .ToListAsync();

            return Ok(stores);
        }

        // PUT /api/admin/stores/{id}/approve - Duyệt Cửa hàng
        [HttpPut("stores/{id}/approve")]
        public async Task<IActionResult> ApproveStore(Guid id)
        {
            var store = await _db.Stores
                .Include(s => s.Owner)
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.Id == id);
            if (store == null) return NotFound();

            if (store.IsApproved) return BadRequest("Cửa hàng đã được duyệt rồi");

            // Duyệt cửa hàng
            store.IsApproved = true;
            store.IsActive = true;

            // Gán Role "Seller" cho OwnerId
            if (store.Owner != null)
            {
                var isInRole = await _userManager.IsInRoleAsync(store.Owner, "Seller");
                if (!isInRole)
                {
                    await _userManager.AddToRoleAsync(store.Owner, "Seller");
                }
            }

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
                store.OwnerId,
                Message = "Đã duyệt cửa hàng và gán role Seller cho chủ cửa hàng"
            });
        }

        // PUT /api/admin/stores/{id}/toggle-active - Tạm khóa/Mở khóa cửa hàng
        [HttpPut("stores/{id}/toggle-active")]
        public async Task<IActionResult> ToggleStoreActive(Guid id)
        {
            var store = await _db.Stores
                .FirstOrDefaultAsync(s => !s.IsDeleted && s.Id == id);
            if (store == null) return NotFound();

            if (!store.IsApproved) return BadRequest("Không thể thay đổi trạng thái cửa hàng chưa được duyệt");

            store.IsActive = !store.IsActive;
            await _db.SaveChangesAsync();

            return Ok(new
            {
                store.Id,
                store.Name,
                store.IsActive,
                Message = store.IsActive ? "Đã mở khóa cửa hàng" : "Đã khóa cửa hàng"
            });
        }

        // GET /api/admin/marketplace/statistics - Lấy thống kê marketplace
        [HttpGet("marketplace/statistics")]
        public async Task<IActionResult> GetStatistics()
        {
            var now = DateTime.UtcNow;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);

            var totalStores = await _db.Stores
                .CountAsync(s => !s.IsDeleted && s.IsApproved);
            var activeStores = await _db.Stores
                .CountAsync(s => !s.IsDeleted && s.IsApproved && s.IsActive);
            var pendingStores = await _db.Stores
                .CountAsync(s => !s.IsDeleted && !s.IsApproved);
            var inactiveStores = await _db.Stores
                .CountAsync(s => !s.IsDeleted && s.IsApproved && !s.IsActive);

            var totalProducts = await _db.Products
                .CountAsync(p => !p.IsDeleted);
            var activeProducts = await _db.Products
                .CountAsync(p => !p.IsDeleted && p.IsAvailable);
            var outOfStockProducts = await _db.Products
                .CountAsync(p => !p.IsDeleted && !p.IsAvailable);

            var ordersThisMonth = await _db.Orders
                .CountAsync(o => !o.IsDeleted && o.CreatedAtUtc >= startOfMonth);
            var completedOrdersThisMonth = await _db.Orders
                .CountAsync(o => !o.IsDeleted && o.Status == OrderStatus.Completed && o.CreatedAtUtc >= startOfMonth);
            var pendingOrders = await _db.Orders
                .CountAsync(o => !o.IsDeleted && o.Status == OrderStatus.Pending);

            var revenueThisMonth = await _db.Orders
                .Where(o => !o.IsDeleted && o.Status == OrderStatus.Completed && o.CreatedAtUtc >= startOfMonth)
                .SumAsync(o => (decimal?)o.TotalAmount) ?? 0;

            return Ok(new
            {
                TotalStores = totalStores,
                ActiveStores = activeStores,
                PendingStores = pendingStores,
                InactiveStores = inactiveStores,
                TotalProducts = totalProducts,
                ActiveProducts = activeProducts,
                OutOfStockProducts = outOfStockProducts,
                OrdersThisMonth = ordersThisMonth,
                CompletedOrdersThisMonth = completedOrdersThisMonth,
                PendingOrders = pendingOrders,
                RevenueThisMonth = revenueThisMonth
            });
        }
    }
}

