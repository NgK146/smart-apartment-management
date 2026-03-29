using ICitizen.Domain;
using ICitizen.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;

namespace ICitizen.Data;

public class ApplicationDbContext : IdentityDbContext<AppUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<Apartment> Apartments => Set<Apartment>();
    public DbSet<ResidentProfile> ResidentProfiles => Set<ResidentProfile>();
    public DbSet<Notification> Notifications => Set<Notification>();

    public DbSet<Complaint> Complaints => Set<Complaint>();
    public DbSet<ComplaintComment> ComplaintComments => Set<ComplaintComment>();

    public DbSet<FeeDefinition> FeeDefinitions => Set<FeeDefinition>();
    public DbSet<MeterReading> MeterReadings => Set<MeterReading>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<InvoiceLine> InvoiceLines => Set<InvoiceLine>();
    public DbSet<Payment> Payments => Set<Payment>();

    public DbSet<Amenity> Amenities => Set<Amenity>();
    public DbSet<AmenityBooking> AmenityBookings => Set<AmenityBooking>();
    public DbSet<Category> Categories => Set<Category>();

    public DbSet<Locker> Lockers => Set<Locker>();
    public DbSet<Compartment> Compartments => Set<Compartment>();
    public DbSet<LockerTransaction> LockerTransactions => Set<LockerTransaction>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<ParkingPlan> ParkingPlans => Set<ParkingPlan>();
    public DbSet<ParkingPass> ParkingPasses => Set<ParkingPass>();
    public DbSet<Domain.ServiceProvider> ServiceProviders => Set<Domain.ServiceProvider>();
    public DbSet<RentalContract> RentalContracts => Set<RentalContract>();
    public DbSet<InternalTask> InternalTasks => Set<InternalTask>();
    public DbSet<ConciergeRequest> ConciergeRequests => Set<ConciergeRequest>();
    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();

    // Support desk entities
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<SupportTicketMessage> SupportTicketMessages => Set<SupportTicketMessage>();
    public DbSet<CommunityMessage> CommunityMessages => Set<CommunityMessage>();
    
    // Community Posts entities
    public DbSet<CommunityPost> CommunityPosts => Set<CommunityPost>();
    public DbSet<PostComment> PostComments => Set<PostComment>();
    public DbSet<PostLike> PostLikes => Set<PostLike>();
    public DbSet<PostCommentLike> PostCommentLikes => Set<PostCommentLike>();

    // Marketplace entities
    public DbSet<Store> Stores => Set<Store>();
    public DbSet<ProductCategory> ProductCategories => Set<ProductCategory>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderDetail> OrderDetails => Set<OrderDetail>();
    public DbSet<StoreReview> StoreReviews => Set<StoreReview>();

    // Visitor Access entities
    public DbSet<VisitorAccess> VisitorAccesses => Set<VisitorAccess>();

    // Activity Suggestion entities
    public DbSet<Activity> Activities => Set<Activity>();
    public DbSet<Bill> Bills => Set<Bill>();
    public DbSet<CommunityEvent> CommunityEvents => Set<CommunityEvent>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        // ===== Support desk =====
        b.Entity<SupportTicket>(e =>
        {
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.CreatedById).HasMaxLength(450).IsRequired();
            e.Property(x => x.AssignedToId).HasMaxLength(450);
            e.Property(x => x.ApartmentCode).HasMaxLength(50);
            e.Property(x => x.Category).HasMaxLength(50);
        });

        b.Entity<SupportTicketMessage>(e =>
        {
            e.Property(x => x.SenderId).HasMaxLength(450).IsRequired();
            e.Property(x => x.Content).IsRequired();
            e.Property(x => x.AttachmentUrl).HasMaxLength(1024);

            e.HasOne(m => m.Ticket)
                .WithMany(t => t.Messages)
                .HasForeignKey(m => m.TicketId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<CommunityMessage>(e =>
        {
            e.Property(x => x.Room).HasMaxLength(64).IsRequired();
            e.Property(x => x.SenderId).HasMaxLength(450);
            e.Property(x => x.SenderName).HasMaxLength(256);
            e.Property(x => x.Content).IsRequired();
            e.Property(x => x.AttachmentType).HasMaxLength(32);
            e.Property(x => x.AttachmentUrl).HasMaxLength(1024);
            e.HasIndex(x => new { x.Room, x.CreatedAtUtc });
        });

        // ===== Community Posts =====
        b.Entity<CommunityPost>(e =>
        {
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.Content).IsRequired();
            e.Property(x => x.CreatedById).HasMaxLength(450).IsRequired();
            e.Property(x => x.CreatedByName).HasMaxLength(256).IsRequired();
            e.Property(x => x.ApartmentCode).HasMaxLength(50);
            e.Property(x => x.NotificationId).IsRequired(false); // Cho phép null
            e.Property(x => x.ImageUrls).HasConversion(
                v => string.Join(",", v),
                v => v.Split(",", StringSplitOptions.RemoveEmptyEntries).ToList()
            ).Metadata.SetValueComparer(
                new ValueComparer<List<string>>(
                    (c1, c2) => c1 != null && c2 != null && c1.SequenceEqual(c2),
                    c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
                    c => c.ToList()
                )
            );
            e.HasIndex(x => new { x.Type, x.CreatedAtUtc });
            e.HasIndex(x => x.CreatedById);
            e.HasIndex(x => x.NotificationId); // Index cho NotificationId để tìm nhanh
            
            e.HasMany(x => x.Comments)
                .WithOne(c => c.Post)
                .HasForeignKey(c => c.PostId)
                .OnDelete(DeleteBehavior.Cascade);
            
            e.HasMany(x => x.Likes)
                .WithOne(l => l.Post)
                .HasForeignKey(l => l.PostId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<PostComment>(e =>
        {
            e.Property(x => x.Content).IsRequired();
            e.Property(x => x.CreatedById).HasMaxLength(450).IsRequired();
            e.Property(x => x.CreatedByName).HasMaxLength(256).IsRequired();
            e.HasIndex(x => x.PostId);
            e.HasIndex(x => x.CreatedById);
            e.HasIndex(x => x.ParentCommentId);
            
            // Relationship: Comment có thể có parent comment (reply)
            e.HasOne(x => x.ParentComment)
                .WithMany(x => x.Replies)
                .HasForeignKey(x => x.ParentCommentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<PostLike>(e =>
        {
            e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
            e.HasIndex(x => new { x.PostId, x.UserId }).IsUnique();
            e.HasIndex(x => x.PostId);
        });

        b.Entity<PostCommentLike>(e =>
        {
            e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
            e.HasIndex(x => new { x.CommentId, x.UserId }).IsUnique();
            e.HasIndex(x => x.CommentId);
            
            // Relationship: CommentLike thuộc về PostComment
            e.HasOne(x => x.Comment)
                .WithMany(x => x.Likes)
                .HasForeignKey(x => x.CommentId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ===== Apartments / Residents / … (giữ nguyên bản của bạn) =====
        b.Entity<Apartment>().HasIndex(x => x.Code).IsUnique();
        b.Entity<Apartment>().Property(x => x.AreaM2).HasPrecision(18, 2);

        b.Entity<ResidentProfile>()
            .HasOne(x => x.Apartment)
            .WithMany(a => a.Residents)
            .HasForeignKey(x => x.ApartmentId)
            .OnDelete(DeleteBehavior.Restrict);

        b.Entity<InvoiceLine>().Property(x => x.Quantity).HasPrecision(18, 2);
        b.Entity<InvoiceLine>().Property(x => x.UnitPrice).HasPrecision(18, 2);
        b.Entity<InvoiceLine>().Property(x => x.Amount).HasPrecision(18, 2);

        b.Entity<Invoice>().Property(x => x.TotalAmount).HasPrecision(18, 2);
        b.Entity<FeeDefinition>().Property(x => x.Amount).HasPrecision(18, 2);
        
        // MeterReading relationships
        b.Entity<MeterReading>()
            .HasOne(mr => mr.Apartment)
            .WithMany()
            .HasForeignKey(mr => mr.ApartmentId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<MeterReading>()
            .HasOne(mr => mr.FeeDefinition)
            .WithMany()
            .HasForeignKey(mr => mr.FeeDefinitionId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<MeterReading>().Property(x => x.Reading).HasPrecision(18, 2);
        b.Entity<MeterReading>().Property(x => x.PreviousReading).HasPrecision(18, 2);
        b.Entity<MeterReading>().HasIndex(x => new { x.ApartmentId, x.FeeDefinitionId, x.Month, x.Year }).IsUnique();
        b.Entity<Amenity>().Property(x => x.PricePerHour).HasPrecision(18, 2);
        b.Entity<AmenityBooking>().Property(x => x.Price).HasPrecision(18, 2);
        
        // ===== Categories =====
        b.Entity<Category>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.Icon).HasMaxLength(50);
            e.HasIndex(x => x.Name).IsUnique();
            e.HasIndex(x => new { x.IsActive, x.DisplayOrder });
        });
        b.Entity<Payment>().Property(x => x.Amount).HasPrecision(18, 2);
        b.Entity<ParkingPlan>().Property(x => x.Price).HasPrecision(18, 2);

        // ===== Locker Management System =====
        // Locker
        b.Entity<Locker>(e =>
        {
            e.Property(x => x.Code).HasMaxLength(50).IsRequired();
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Location).HasMaxLength(200);
            e.HasIndex(x => x.Code).IsUnique();
        });

        // Compartment - PROPER 1-to-1 with Apartment
        b.Entity<Compartment>(e =>
        {
            e.Property(x => x.Code).HasMaxLength(50).IsRequired();
            e.Property(x => x.ApartmentId).IsRequired();  // NOT NULL
            e.HasIndex(x => x.Code).IsUnique();
            e.HasIndex(x => x.ApartmentId).IsUnique(); // Enforce 1-to-1
            
            e.HasOne(x => x.Locker)
                .WithMany(l => l.Compartments)
                .HasForeignKey(x => x.LockerId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configure 1-to-1 relationship: Apartment <-> Compartment
        b.Entity<Apartment>()
            .HasOne(a => a.Compartment)
            .WithOne(c => c.Apartment)
            .HasForeignKey<Compartment>(c => c.ApartmentId)
            .OnDelete(DeleteBehavior.Restrict);

        // LockerTransaction
        b.Entity<LockerTransaction>(e =>
        {
            e.Property(x => x.SecurityUserId).HasMaxLength(450).IsRequired();
            e.Property(x => x.DropTokenHash).HasMaxLength(256);
            e.Property(x => x.PickupTokenHash).HasMaxLength(256);
            e.Property(x => x.Notes).HasMaxLength(500);
            
            e.HasOne(x => x.Apartment)
                .WithMany()
                .HasForeignKey(x => x.ApartmentId)
                .OnDelete(DeleteBehavior.Restrict);
                
            e.HasOne(x => x.Compartment)
                .WithMany()
                .HasForeignKey(x => x.CompartmentId)
                .OnDelete(DeleteBehavior.Restrict);
                
            e.HasIndex(x => x.Status);
            e.HasIndex(x => x.ApartmentId);
            e.HasIndex(x => x.SecurityUserId);
        });

        // AuditLog
        b.Entity<AuditLog>(e =>
        {
            e.Property(x => x.Action).HasMaxLength(100).IsRequired();
            e.Property(x => x.ByUserId).HasMaxLength(450).IsRequired();
            e.Property(x => x.Note).HasMaxLength(500);
            
            e.HasOne(x => x.Transaction)
                .WithMany()
                .HasForeignKey(x => x.TransactionId)
                .OnDelete(DeleteBehavior.Cascade);
                
            e.HasIndex(x => x.TransactionId);
            e.HasIndex(x => new { x.TransactionId, x.At });
        });

        // ===== Complaints =====
        // Title hợp lý 256 ký tự; Category/Status là enum -> để mặc định (int) để không phá schema cũ
        b.Entity<Complaint>()
            .Property(x => x.Title)
            .HasMaxLength(256);

        // Quan hệ: Complaint (1) - (n) ComplaintComment, khóa ngoại ComplaintId (Guid)
        b.Entity<ComplaintComment>()
            .HasOne(cc => cc.Complaint)
            .WithMany(c => c.Comments)
            .HasForeignKey(cc => cc.ComplaintId)
            .OnDelete(DeleteBehavior.Cascade);

        // Vehicles
        b.Entity<Vehicle>()
            .HasOne(v => v.ResidentProfile)
            .WithMany()
            .HasForeignKey(v => v.ResidentProfileId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<Vehicle>().HasIndex(x => x.LicensePlate).IsUnique();

        // Parking Plans
        b.Entity<ParkingPlan>()
            .HasMany(p => p.ParkingPasses)
            .WithOne(pp => pp.ParkingPlan)
            .HasForeignKey(pp => pp.ParkingPlanId)
            .OnDelete(DeleteBehavior.Restrict);

        // Parking Passes
        b.Entity<ParkingPass>()
            .HasOne(pp => pp.Vehicle)
            .WithMany()
            .HasForeignKey(pp => pp.VehicleId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<ParkingPass>()
            .HasOne(pp => pp.Invoice)
            .WithMany()
            .HasForeignKey(pp => pp.InvoiceId)
            .OnDelete(DeleteBehavior.SetNull);

        // User notifications
        b.Entity<UserNotification>(e =>
        {
            e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.Message).HasMaxLength(2000).IsRequired();
            e.Property(x => x.Type).HasMaxLength(50).HasDefaultValue("General");
            e.Property(x => x.RefType).HasMaxLength(50);
            e.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            e.HasIndex(x => new { x.UserId, x.IsDeleted });
        });
        b.Entity<ParkingPass>().HasIndex(x => x.PassCode).IsUnique();

        // Rental Contracts
        b.Entity<RentalContract>()
            .HasOne(rc => rc.Apartment)
            .WithMany()
            .HasForeignKey(rc => rc.ApartmentId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<RentalContract>()
            .HasOne(rc => rc.ResidentProfile)
            .WithMany()
            .HasForeignKey(rc => rc.ResidentProfileId)
            .OnDelete(DeleteBehavior.Restrict);
        b.Entity<RentalContract>().Property(x => x.MonthlyRent).HasPrecision(18, 2);
        b.Entity<RentalContract>().Property(x => x.Deposit).HasPrecision(18, 2);

        // Internal Tasks
        b.Entity<InternalTask>()
            .HasOne(t => t.Apartment)
            .WithMany()
            .HasForeignKey(t => t.ApartmentId)
            .OnDelete(DeleteBehavior.Restrict);

        // Concierge requests
        b.Entity<ConciergeRequest>(e =>
        {
            e.Property(x => x.ServiceId).HasMaxLength(50).IsRequired();
            e.Property(x => x.ServiceName).HasMaxLength(200);
            e.Property(x => x.UserId).HasMaxLength(450).IsRequired();
            e.Property(x => x.Notes).HasMaxLength(1000);
            e.HasIndex(x => x.UserId);
            e.HasIndex(x => x.Status);
        });

        // ===== Marketplace =====
        b.Entity<Store>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(1000);
            e.Property(x => x.Phone).HasMaxLength(20);
            e.Property(x => x.LogoUrl).HasMaxLength(500);
            e.Property(x => x.CoverImageUrl).HasMaxLength(500);
            e.Property(x => x.OwnerId).HasMaxLength(450).IsRequired();
            e.HasIndex(x => x.OwnerId);
            e.HasIndex(x => x.IsApproved);
            e.HasIndex(x => x.IsActive);
        });

        b.Entity<ProductCategory>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.HasOne(x => x.Store)
                .WithMany(s => s.ProductCategories)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Product>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(1000);
            e.Property(x => x.Price).HasPrecision(18, 2);
            e.Property(x => x.ImageUrl).HasMaxLength(500);
            e.HasOne(x => x.Store)
                .WithMany(s => s.Products)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.ProductCategory)
                .WithMany(c => c.Products)
                .HasForeignKey(x => x.ProductCategoryId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.StoreId);
            e.HasIndex(x => x.IsAvailable);
        });

        b.Entity<Order>(e =>
        {
            e.Property(x => x.TotalAmount).HasPrecision(18, 2);
            e.Property(x => x.Notes).HasMaxLength(500);
            e.Property(x => x.BuyerId).HasMaxLength(450).IsRequired();
            e.HasOne(x => x.Buyer)
                .WithMany()
                .HasForeignKey(x => x.BuyerId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Store)
                .WithMany(s => s.Orders)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.BuyerId);
            e.HasIndex(x => x.StoreId);
            e.HasIndex(x => x.Status);
        });

        b.Entity<OrderDetail>(e =>
        {
            e.Property(x => x.PriceAtPurchase).HasPrecision(18, 2);
            e.HasOne(x => x.Order)
                .WithMany(o => o.OrderDetails)
                .HasForeignKey(x => x.OrderId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Product)
                .WithMany(p => p.OrderDetails)
                .HasForeignKey(x => x.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<StoreReview>(e =>
        {
            e.Property(x => x.Comment).HasMaxLength(1000);
            e.Property(x => x.ResidentId).HasMaxLength(450).IsRequired();
            e.HasOne(x => x.Store)
                .WithMany(s => s.Reviews)
                .HasForeignKey(x => x.StoreId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Resident)
                .WithMany()
                .HasForeignKey(x => x.ResidentId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Order)
                .WithMany(o => o.Reviews)
                .HasForeignKey(x => x.OrderId)
                .OnDelete(DeleteBehavior.SetNull);
            e.HasIndex(x => x.StoreId);
        });

        // ===== Visitor Access =====
        b.Entity<VisitorAccess>(e =>
        {
            e.Property(x => x.ApartmentCode).HasMaxLength(20).IsRequired();
            e.Property(x => x.VisitorName).HasMaxLength(200).IsRequired();
            e.Property(x => x.VisitorPhone).HasMaxLength(20);
            e.Property(x => x.VisitorEmail).HasMaxLength(200);
            e.Property(x => x.VisitTime).HasMaxLength(10);
            e.Property(x => x.Purpose).HasMaxLength(500);
            e.Property(x => x.QrCode).HasMaxLength(100).IsRequired();
            e.Property(x => x.QrCodeUrl).HasMaxLength(500);
            e.Property(x => x.Status).HasMaxLength(20).IsRequired();
            e.HasIndex(x => x.QrCode).IsUnique();
            e.HasIndex(x => x.ResidentId);
            e.HasOne(x => x.Resident)
                .WithMany()
                .HasForeignKey(x => x.ResidentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // ===== Activity Suggestions =====
        b.Entity<Activity>(e =>
        {
            e.Property(x => x.Code).HasMaxLength(50).IsRequired();
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(1000);
            e.Property(x => x.Tags).HasMaxLength(500);
            e.HasIndex(x => x.Code).IsUnique();
        });

        b.Entity<Bill>(e =>
        {
            e.Property(x => x.Type).HasMaxLength(50).IsRequired();
            e.HasOne(x => x.ResidentProfile)
                .WithMany()
                .HasForeignKey(x => x.ResidentProfileId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => new { x.ResidentProfileId, x.Type, x.DueDate });
        });

        b.Entity<CommunityEvent>(e =>
        {
            e.Property(x => x.Title).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(1000);
            e.Property(x => x.Building).HasMaxLength(10).IsRequired();
            e.Property(x => x.Tags).HasMaxLength(500);
            e.HasIndex(x => new { x.Building, x.Floor, x.StartTime });
        });

        // Seed 22 Activities
        b.Entity<Activity>().HasData(
            new Activity { Id = 1, Code = "PAY_SERVICE_BILL", Title = "Thanh toán phí dịch vụ tháng này", Description = "Hôm nay là hạn thanh toán phí dịch vụ, vui lòng kiểm tra và thanh toán.", Tags = "tai_chinh,bat_buoc,buoi_sang" },
            new Activity { Id = 2, Code = "PAY_ELECTRIC_BILL", Title = "Thanh toán tiền điện", Description = "Kiểm tra và thanh toán hóa đơn tiền điện tháng này.", Tags = "tai_chinh,bat_buoc,buoi_sang" },
            new Activity { Id = 3, Code = "PAY_WATER_BILL", Title = "Thanh toán tiền nước", Description = "Kiểm tra và thanh toán hóa đơn tiền nước tháng này.", Tags = "tai_chinh,bat_buoc,buoi_sang" },
            new Activity { Id = 4, Code = "REGISTER_PARKING", Title = "Đăng ký / gia hạn chỗ gửi xe", Description = "Kiểm tra thời hạn chỗ gửi xe ô tô / xe máy và gia hạn nếu sắp hết.", Tags = "tai_chinh,bat_buoc,cong_viec" },
            new Activity { Id = 5, Code = "CHECK_MAILBOX", Title = "Kiểm tra hộp thư cư dân", Description = "Kiểm tra hộp thư tầng trệt để xem có thư hoặc thông báo giấy không.", Tags = "cong_viec,buoi_sang,bat_buoc" },
            new Activity { Id = 6, Code = "CHECK_FIRE_SAFETY", Title = "Kiểm tra an toàn phòng cháy", Description = "Kiểm tra bình chữa cháy, lối thoát hiểm gần căn hộ.", Tags = "cong_viec,bat_buoc,an_toan" },
            new Activity { Id = 7, Code = "GO_GYM_MORNING", Title = "Tập gym buổi sáng", Description = "Dành 30 phút tập gym tại phòng tập tầng 3 để khởi động ngày mới.", Tags = "suc_khoe,trong_nha,buoi_sang" },
            new Activity { Id = 8, Code = "GO_GYM_EVENING", Title = "Tập gym buổi tối", Description = "Thư giãn sau giờ làm bằng buổi tập nhẹ tại phòng gym.", Tags = "suc_khoe,trong_nha,buoi_toi" },
            new Activity { Id = 9, Code = "GO_POOL_AFTERNOON", Title = "Đi bơi buổi chiều", Description = "Thư giãn tại hồ bơi tầng 5, phù hợp khi thời tiết nóng.", Tags = "suc_khoe,giai_tri,ngoai_troi,buoi_chieu" },
            new Activity { Id = 10, Code = "WALK_GARDEN", Title = "Đi dạo khu vườn trên mái", Description = "Đi dạo nhẹ khu vườn tầng thượng, tốt cho sức khỏe.", Tags = "suc_khoe,ngoai_troi,nguoi_gia,buoi_chieu" },
            new Activity { Id = 11, Code = "JOIN_WEEKEND_EVENT", Title = "Tham gia sự kiện cộng đồng cuối tuần", Description = "Sự kiện giao lưu cư dân tại sảnh tầng 1.", Tags = "su_kien,social,hoat_dong_gia_dinh,buoi_toi,cuoi_tuan" },
            new Activity { Id = 12, Code = "JOIN_KIDS_WORKSHOP", Title = "Cho bé tham gia hoạt động thiếu nhi", Description = "Workshop / trò chơi cho trẻ em tại khu vui chơi.", Tags = "su_kien,tre_em,hoat_dong_gia_dinh,buoi_chieu,cuoi_tuan" },
            new Activity { Id = 13, Code = "USE_STUDY_ROOM", Title = "Sử dụng phòng học / làm việc chung", Description = "Đến phòng học chung để tập trung làm việc hoặc học tập.", Tags = "hoc_tap,trong_nha,buoi_chieu" },
            new Activity { Id = 14, Code = "QUIET_HOURS_REMINDER", Title = "Giữ yên tĩnh giờ nghỉ", Description = "Nhắc nhở hạn chế tiếng ồn sau 22h để không ảnh hưởng hàng xóm.", Tags = "cong_dong,buoi_toi" },
            new Activity { Id = 15, Code = "NIGHT_SECURITY_CHECK", Title = "Kiểm tra khóa cửa và an ninh", Description = "Kiểm tra khóa cửa chính, cửa sổ, ban công trước khi đi ngủ.", Tags = "an_ninh,an_toan,buoi_toi,bat_buoc" },
            new Activity { Id = 16, Code = "ORDER_GROCERIES_ONLINE", Title = "Đặt mua đồ ăn / nhu yếu phẩm", Description = "Đặt nhu yếu phẩm online, phù hợp khi trời mưa hoặc bận.", Tags = "mua_sam,trong_nha,buoi_toi" },
            new Activity { Id = 17, Code = "BOOK_BBQ_AREA", Title = "Đặt khu BBQ cuối tuần", Description = "Đặt lịch sử dụng khu BBQ cho gia đình/bạn bè.", Tags = "giai_tri,ngoai_troi,buoi_toi,cuoi_tuan,social" },
            new Activity { Id = 18, Code = "CLEAN_AIRCON", Title = "Lên lịch vệ sinh điều hòa", Description = "Đặt lịch vệ sinh điều hòa định kỳ để tiết kiệm điện và tốt cho sức khỏe.", Tags = "cong_viec,bao_tri,trong_nha" },
            new Activity { Id = 19, Code = "REGISTER_VISITOR", Title = "Đăng ký khách đến chơi", Description = "Tạo trước mã QR cho khách để vào cổng dễ dàng.", Tags = "cong_viec,an_ninh,buoi_chieu" },
            new Activity { Id = 20, Code = "ELDERLY_EXERCISE", Title = "Tập thể dục nhẹ cho người lớn tuổi", Description = "Các bài tập nhẹ nhàng tại khu sinh hoạt chung.", Tags = "suc_khoe,nguoi_gia,buoi_sang,trong_nha" },
            new Activity { Id = 21, Code = "KIDS_PLAYGROUND", Title = "Cho bé chơi tại khu vui chơi", Description = "Đưa trẻ xuống khu vui chơi trẻ em trong khuôn viên.", Tags = "tre_em,hoat_dong_gia_dinh,ngoai_troi,buoi_chieu" },
            new Activity { Id = 22, Code = "CAR_WASH", Title = "Rửa xe tại khu dịch vụ", Description = "Đưa xe tới khu rửa xe trong chung cư.", Tags = "dich_vu,ngoai_troi,buoi_sang" }
        );

        // Seed sample Community Events (using fixed GUIDs for seed data)
        var today = DateTime.Today;
        b.Entity<CommunityEvent>().HasData(
            new CommunityEvent
            {
                Id = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                Title = "Sinh hoạt cộng đồng cư dân tòa A",
                Description = "Giao lưu cuối tuần tại sảnh tầng 1 tòa A.",
                StartTime = today.AddHours(19),
                EndTime = today.AddHours(21),
                Building = "A",
                Floor = 1,
                Tags = "su_kien,social,hoat_dong_gia_dinh",
                CreatedAtUtc = DateTime.UtcNow
            },
            new CommunityEvent
            {
                Id = Guid.Parse("22222222-2222-2222-2222-222222222222"),
                Title = "Hoạt động thiếu nhi tầng 5 tòa A",
                Description = "Trò chơi và vẽ tranh cho trẻ em.",
                StartTime = today.AddHours(16),
                EndTime = today.AddHours(18),
                Building = "A",
                Floor = 5,
                Tags = "su_kien,tre_em,hoat_dong_gia_dinh",
                CreatedAtUtc = DateTime.UtcNow
            }
        );
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker.Entries<Domain.BaseEntity>();
        var now = DateTime.UtcNow;

        foreach (var e in entries)
        {
            if (e.State == EntityState.Added) e.Entity.CreatedAtUtc = now;
            if (e.State == EntityState.Modified) e.Entity.UpdatedAtUtc = now;
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
