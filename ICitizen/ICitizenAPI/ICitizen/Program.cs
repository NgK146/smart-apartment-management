using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using ICitizen.Auth;
using ICitizen.Data;
using ICitizen.Domain;
using ICitizen.Models; // AppUser nằm trong namespace này theo dự án của bạn
using ICitizen.Services;
using ICitizen.Application.Interfaces;
using ICitizen.Application.Recommendation;
using ICitizen.Application.Services;
using ICitizen.Infrastructure.Repositories;
using ICitizen.Infrastructure.Weather;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using PayOS;

var builder = WebApplication.CreateBuilder(args);

// -------------------- DB --------------------
builder.Services.AddDbContext<ApplicationDbContext>(opts =>
    opts.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sql => sql.UseCompatibilityLevel(120)));

// -------------------- Identity --------------------
builder.Services
    .AddIdentityCore<AppUser>(opt =>
    {
        opt.Password.RequireNonAlphanumeric = false;
        opt.Password.RequireUppercase = false;
        opt.Password.RequiredLength = 6;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddSignInManager<SignInManager<AppUser>>()
    .AddDefaultTokenProviders();

// -------------------- JWT --------------------
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()!;

// -------------------- VNPay --------------------
builder.Services.Configure<ICitizen.Services.VnPaySettings>(builder.Configuration.GetSection("VnPay"));
builder.Services.AddScoped<ICitizen.Services.IVnPayService, ICitizen.Services.VnPayService>();
var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key));

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = signingKey,
            ClockSkew = TimeSpan.Zero,
            ValidateLifetime = true
        };

        // Cấu hình JWT cho SignalR
        o.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                
                // Nếu request đến SignalR hub, lấy token từ query string
                if (!string.IsNullOrEmpty(accessToken) &&
                    (path.StartsWithSegments("/hubs/community") ||
                     path.StartsWithSegments("/hubs/support") ||
                     path.StartsWithSegments("/hubs/payment")))
                {
                    context.Token = accessToken;
                }
                
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddHttpContextAccessor(); // Cần cho VisitorController
builder.Services.AddScoped<IInvoicePaymentService, InvoicePaymentService>();
builder.Services.AddScoped<IPaymentNotificationService, PaymentNotificationService>();

// -------------------- SMS Service --------------------
builder.Services.AddHttpClient("SmsClient", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.Add("User-Agent", "ICitizen-API/1.0");
}).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
{
    AllowAutoRedirect = true, // Cho phép follow redirect
    MaxAutomaticRedirections = 5
});
builder.Services.AddScoped<ISmsService, SmsService>();

// -------------------- Email Sender --------------------
builder.Services.AddScoped<IEmailSender, EmailSender>();

// -------------------- Weather Service --------------------
builder.Services.AddHttpClient<IWeatherService, OpenWeatherService>();
builder.Services.AddHttpClient<ICitizen.Services.WeatherService>();
builder.Services.AddHttpClient<ICitizen.Services.GroqService>();
builder.Services.AddHttpClient<ICitizen.Services.OsmService>();

// -------------------- Blockchain Service --------------------
builder.Services.AddSingleton<BlockchainService>();
builder.Services.AddSingleton<PaymentBlockchainService>();

// -------------------- Activity Suggestions (Clean Architecture) --------------------
builder.Services.AddScoped<ISuggestionRepository, EfSuggestionRepository>();
builder.Services.AddScoped<ISuggestionRuleEngine, SuggestionRuleEngine>();
builder.Services.AddScoped<ISuggestionService, SuggestionService>();

// -------------------- Locker Management --------------------
builder.Services.AddScoped<ILockerService, LockerService>();

// -------------------- PayOS --------------------
builder.Services.AddSingleton(sp =>
{
    var cfg = builder.Configuration;
    var options = new PayOSOptions
    {
        ClientId = cfg["PayOS:ClientId"],
        ApiKey = cfg["PayOS:ApiKey"],
        ChecksumKey = cfg["PayOS:ChecksumKey"],
        PartnerCode = cfg["PayOS:PartnerCode"]
    };
    return new PayOSClient(options);
});

// -------------------- Controllers + JSON --------------------
builder.Services
    .AddControllers()
    .AddJsonOptions(o =>
    {
        // Enum trả về dạng chuỗi cho front-end (Flutter) đọc dễ hơn
        o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
        // Đảm bảo serialize sang camelCase cho Flutter
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });

builder.Services.AddEndpointsApiExplorer();

// -------------------- Swagger --------------------
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "ICitizen API", Version = "v1" });

    // Bearer JWT
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "JWT Authorization header. Ví dụ: 'Bearer {token}'",
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// -------------------- CORS (Dev) --------------------
builder.Services.AddCors(opt =>
{
    opt.AddPolicy("Dev", p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

// Hosted services
builder.Services.AddHostedService<ICitizen.Services.AmenityReminderService>();

// -------------------- SignalR (Chat) --------------------
builder.Services.AddSignalR();

// -------------------- Memory Cache (for rate limiting) --------------------
builder.Services.AddMemoryCache();

var app = builder.Build();

// -------------------- Pipeline --------------------
app.UseSwagger();
app.UseSwaggerUI();

// (khuyến nghị) ép redirect sang HTTPS khi khả dụng
app.UseHttpsRedirection();
if (string.IsNullOrEmpty(app.Environment.WebRootPath))
{
    app.Environment.WebRootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
}
Directory.CreateDirectory(Path.Combine(app.Environment.WebRootPath!, "uploads", "community"));
app.UseStaticFiles();

app.UseCors("Dev");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Tạm thời đảm bảo endpoint mở cửa khả dụng cả khi AccessController không được phát hiện
app.MapPost("/api/Access/open-door", async ([FromBody] DoorRequest req, ICitizen.Services.BlockchainService bc) =>
{
    // Giả lập mở cửa thành công và ghi log blockchain
    string logContent = $"OPEN_DOOR_SUCCESS by {req.Username}";
    string txHash = await bc.WriteLogAsync(req.RoomNumber, logContent);
    return Results.Ok(new
    {
        status = "Door Opened",
        timestamp = DateTime.Now,
        security_proof = txHash
    });
});

// SignalR Hubs (phải đặt sau UseAuthentication và UseAuthorization)
app.MapHub<ICitizen.Hubs.CommunityHub>("/hubs/community");
app.MapHub<ICitizen.Hubs.SupportHub>("/hubs/support");
app.MapHub<ICitizen.Hubs.PaymentHub>("/hubs/payment");
app.MapHub<ICitizen.Hubs.NotificationHub>("/hubs/notifications");
app.MapHub<ICitizen.Hubs.LockerHub>("/hubs/locker");

// Seed role + admin mặc định
await SeedAsync(app.Services);

// Seed Bills for testing
await SeedBillsAsync(app.Services);

// Chạy migration để thêm cột Type vào Invoices
await RunMigrationIfNeededAsync(app.Services);

app.Run();

static async Task SeedAsync(IServiceProvider services)
{
    using var scope = services.CreateScope();
    var roleMgr = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
    var userMgr = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();

    // Các role chuẩn
    string[] roles = new[] { "Resident", "Manager", "Security", "Vendor", "Seller" };
    foreach (var r in roles)
        if (!await roleMgr.RoleExistsAsync(r))
            await roleMgr.CreateAsync(new IdentityRole(r));

    // Tài khoản admin mặc định
    var admin = await userMgr.FindByNameAsync("admin");
    if (admin is null)
    {
        admin = new AppUser
        {
            UserName = "admin",
            Email = "admin@icitizen.local",
            FullName = "Ban quản lý",
            IsApproved = true
        };
        // NHỚ đổi mật khẩu sau khi deploy
        var created = await userMgr.CreateAsync(admin, "Admin@123");
        if (created.Succeeded)
        {
            await userMgr.AddToRoleAsync(admin, "Manager");
            Console.WriteLine("✓ Admin user created successfully.");
        }
    }

    // Tài khoản Security mặc định (để test Locker module)
    var security = await userMgr.FindByNameAsync("security1");
    if (security is null)
    {
        security = new AppUser
        {
            UserName = "security1",
            Email = "security1@icitizen.com",
            FullName = "Bảo Vệ 1",
            PhoneNumber = "0900000001",
            IsApproved = true,
            EmailConfirmed = true,
            PhoneNumberConfirmed = true
        };
        var created = await userMgr.CreateAsync(security, "Security@123");
        if (created.Succeeded)
        {
            await userMgr.AddToRoleAsync(security, "Security");
            Console.WriteLine("✓ Security user 'security1' created successfully.");
            Console.WriteLine("  Username: security1");
            Console.WriteLine("  Password: Security@123");
        }
        else
        {
            Console.WriteLine($"✗ Failed to create Security user: {string.Join(", ", created.Errors.Select(e => e.Description))}");
        }
    }
}

static async Task SeedBillsAsync(IServiceProvider services)
{
    try
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        if (!db.Bills.Any())
        {
            var resident1 = db.ResidentProfiles.FirstOrDefault();
            if (resident1 != null)
            {
                db.Bills.Add(new Bill
                {
                    Id = Guid.NewGuid(),
                    ResidentProfileId = resident1.Id,
                    Type = "Service",
                    DueDate = DateTime.Today,
                    IsPaid = false,
                    CreatedAtUtc = DateTime.UtcNow
                });

                db.Bills.Add(new Bill
                {
                    Id = Guid.NewGuid(),
                    ResidentProfileId = resident1.Id,
                    Type = "Electric",
                    DueDate = DateTime.Today.AddDays(3),
                    IsPaid = false,
                    CreatedAtUtc = DateTime.UtcNow
                });

                await db.SaveChangesAsync();
                Console.WriteLine("✓ Bills seeded successfully.");
            }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: Could not seed bills: {ex.Message}");
    }
}

static async Task RunMigrationIfNeededAsync(IServiceProvider services)
{
    try
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var connection = db.Database.GetDbConnection();
        await connection.OpenAsync();

        using var command = connection.CreateCommand();

        // 1) Đảm bảo cột Type trên Invoices tồn tại
        command.CommandText = @"
            SELECT COUNT(*) 
            FROM sys.columns 
            WHERE object_id = OBJECT_ID(N'[dbo].[Invoices]') 
              AND name = 'Type'";
        var hasInvoiceType = (int)(await command.ExecuteScalarAsync())! > 0;

        if (!hasInvoiceType)
        {
            Console.WriteLine("Adding Type column to Invoices table...");
            command.CommandText = @"
                ALTER TABLE [dbo].[Invoices]
                ADD [Type] INT NOT NULL DEFAULT 0;";
            await command.ExecuteNonQueryAsync();
            Console.WriteLine("✓ Column 'Type' added successfully to Invoices table.");
        }
        else
        {
            Console.WriteLine("Column 'Type' already exists in Invoices table.");
        }

        // 2) Đảm bảo các cột ErrorCode, ErrorMessage trên Payments tồn tại
        command.CommandText = @"
            SELECT COUNT(*) 
            FROM sys.columns 
            WHERE object_id = OBJECT_ID(N'[dbo].[Payments]') 
              AND name = 'ErrorCode'";
        var hasErrorCode = (int)(await command.ExecuteScalarAsync())! > 0;

        if (!hasErrorCode)
        {
            Console.WriteLine("Adding ErrorCode column to Payments table...");
            command.CommandText = @"
                ALTER TABLE [dbo].[Payments]
                ADD [ErrorCode] NVARCHAR(10) NULL;";
            await command.ExecuteNonQueryAsync();
            Console.WriteLine("✓ Column 'ErrorCode' added successfully to Payments table.");
        }
        else
        {
            Console.WriteLine("Column 'ErrorCode' already exists in Payments table.");
        }

        command.CommandText = @"
            SELECT COUNT(*) 
            FROM sys.columns 
            WHERE object_id = OBJECT_ID(N'[dbo].[Payments]') 
              AND name = 'ErrorMessage'";
        var hasErrorMessage = (int)(await command.ExecuteScalarAsync())! > 0;

        if (!hasErrorMessage)
        {
            Console.WriteLine("Adding ErrorMessage column to Payments table...");
            command.CommandText = @"
                ALTER TABLE [dbo].[Payments]
                ADD [ErrorMessage] NVARCHAR(500) NULL;";
            await command.ExecuteNonQueryAsync();
            Console.WriteLine("✓ Column 'ErrorMessage' added successfully to Payments table.");
        }
        else
        {
            Console.WriteLine("Column 'ErrorMessage' already exists in Payments table.");
        }

        await connection.CloseAsync();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: Could not run migration automatically: {ex.Message}");
        // Không throw để app vẫn có thể chạy
    }
}
