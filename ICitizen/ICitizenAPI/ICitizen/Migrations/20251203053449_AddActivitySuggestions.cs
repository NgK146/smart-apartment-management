using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace ICitizen.Migrations
{
    /// <inheritdoc />
    public partial class AddActivitySuggestions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Age",
                table: "ResidentProfiles",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Building",
                table: "ResidentProfiles",
                type: "nvarchar(10)",
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Floor",
                table: "ResidentProfiles",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LifeStyle",
                table: "ResidentProfiles",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PreferredActivitiesJson",
                table: "ResidentProfiles",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Activities",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Tags = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Activities", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Bills",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ResidentProfileId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    DueDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsPaid = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bills", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Bills_ResidentProfiles_ResidentProfileId",
                        column: x => x.ResidentProfileId,
                        principalTable: "ResidentProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CommunityEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    StartTime = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndTime = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Building = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    Floor = table.Column<int>(type: "int", nullable: true),
                    Tags = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommunityEvents", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Activities",
                columns: new[] { "Id", "Code", "Description", "Tags", "Title" },
                values: new object[,]
                {
                    { 1, "PAY_SERVICE_BILL", "Hôm nay là hạn thanh toán phí dịch vụ, vui lòng kiểm tra và thanh toán.", "tai_chinh,bat_buoc,buoi_sang", "Thanh toán phí dịch vụ tháng này" },
                    { 2, "PAY_ELECTRIC_BILL", "Kiểm tra và thanh toán hóa đơn tiền điện tháng này.", "tai_chinh,bat_buoc,buoi_sang", "Thanh toán tiền điện" },
                    { 3, "PAY_WATER_BILL", "Kiểm tra và thanh toán hóa đơn tiền nước tháng này.", "tai_chinh,bat_buoc,buoi_sang", "Thanh toán tiền nước" },
                    { 4, "REGISTER_PARKING", "Kiểm tra thời hạn chỗ gửi xe ô tô / xe máy và gia hạn nếu sắp hết.", "tai_chinh,bat_buoc,cong_viec", "Đăng ký / gia hạn chỗ gửi xe" },
                    { 5, "CHECK_MAILBOX", "Kiểm tra hộp thư tầng trệt để xem có thư hoặc thông báo giấy không.", "cong_viec,buoi_sang,bat_buoc", "Kiểm tra hộp thư cư dân" },
                    { 6, "CHECK_FIRE_SAFETY", "Kiểm tra bình chữa cháy, lối thoát hiểm gần căn hộ.", "cong_viec,bat_buoc,an_toan", "Kiểm tra an toàn phòng cháy" },
                    { 7, "GO_GYM_MORNING", "Dành 30 phút tập gym tại phòng tập tầng 3 để khởi động ngày mới.", "suc_khoe,trong_nha,buoi_sang", "Tập gym buổi sáng" },
                    { 8, "GO_GYM_EVENING", "Thư giãn sau giờ làm bằng buổi tập nhẹ tại phòng gym.", "suc_khoe,trong_nha,buoi_toi", "Tập gym buổi tối" },
                    { 9, "GO_POOL_AFTERNOON", "Thư giãn tại hồ bơi tầng 5, phù hợp khi thời tiết nóng.", "suc_khoe,giai_tri,ngoai_troi,buoi_chieu", "Đi bơi buổi chiều" },
                    { 10, "WALK_GARDEN", "Đi dạo nhẹ khu vườn tầng thượng, tốt cho sức khỏe.", "suc_khoe,ngoai_troi,nguoi_gia,buoi_chieu", "Đi dạo khu vườn trên mái" },
                    { 11, "JOIN_WEEKEND_EVENT", "Sự kiện giao lưu cư dân tại sảnh tầng 1.", "su_kien,social,hoat_dong_gia_dinh,buoi_toi,cuoi_tuan", "Tham gia sự kiện cộng đồng cuối tuần" },
                    { 12, "JOIN_KIDS_WORKSHOP", "Workshop / trò chơi cho trẻ em tại khu vui chơi.", "su_kien,tre_em,hoat_dong_gia_dinh,buoi_chieu,cuoi_tuan", "Cho bé tham gia hoạt động thiếu nhi" },
                    { 13, "USE_STUDY_ROOM", "Đến phòng học chung để tập trung làm việc hoặc học tập.", "hoc_tap,trong_nha,buoi_chieu", "Sử dụng phòng học / làm việc chung" },
                    { 14, "QUIET_HOURS_REMINDER", "Nhắc nhở hạn chế tiếng ồn sau 22h để không ảnh hưởng hàng xóm.", "cong_dong,buoi_toi", "Giữ yên tĩnh giờ nghỉ" },
                    { 15, "NIGHT_SECURITY_CHECK", "Kiểm tra khóa cửa chính, cửa sổ, ban công trước khi đi ngủ.", "an_ninh,an_toan,buoi_toi,bat_buoc", "Kiểm tra khóa cửa và an ninh" },
                    { 16, "ORDER_GROCERIES_ONLINE", "Đặt nhu yếu phẩm online, phù hợp khi trời mưa hoặc bận.", "mua_sam,trong_nha,buoi_toi", "Đặt mua đồ ăn / nhu yếu phẩm" },
                    { 17, "BOOK_BBQ_AREA", "Đặt lịch sử dụng khu BBQ cho gia đình/bạn bè.", "giai_tri,ngoai_troi,buoi_toi,cuoi_tuan,social", "Đặt khu BBQ cuối tuần" },
                    { 18, "CLEAN_AIRCON", "Đặt lịch vệ sinh điều hòa định kỳ để tiết kiệm điện và tốt cho sức khỏe.", "cong_viec,bao_tri,trong_nha", "Lên lịch vệ sinh điều hòa" },
                    { 19, "REGISTER_VISITOR", "Tạo trước mã QR cho khách để vào cổng dễ dàng.", "cong_viec,an_ninh,buoi_chieu", "Đăng ký khách đến chơi" },
                    { 20, "ELDERLY_EXERCISE", "Các bài tập nhẹ nhàng tại khu sinh hoạt chung.", "suc_khoe,nguoi_gia,buoi_sang,trong_nha", "Tập thể dục nhẹ cho người lớn tuổi" },
                    { 21, "KIDS_PLAYGROUND", "Đưa trẻ xuống khu vui chơi trẻ em trong khuôn viên.", "tre_em,hoat_dong_gia_dinh,ngoai_troi,buoi_chieu", "Cho bé chơi tại khu vui chơi" },
                    { 22, "CAR_WASH", "Đưa xe tới khu rửa xe trong chung cư.", "dich_vu,ngoai_troi,buoi_sang", "Rửa xe tại khu dịch vụ" }
                });

            migrationBuilder.InsertData(
                table: "CommunityEvents",
                columns: new[] { "Id", "Building", "CreatedAtUtc", "Description", "EndTime", "Floor", "IsDeleted", "StartTime", "Tags", "Title", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { new Guid("11111111-1111-1111-1111-111111111111"), "A", new DateTime(2025, 12, 3, 5, 34, 49, 258, DateTimeKind.Utc).AddTicks(6598), "Giao lưu cuối tuần tại sảnh tầng 1 tòa A.", new DateTime(2025, 12, 3, 21, 0, 0, 0, DateTimeKind.Local), 1, false, new DateTime(2025, 12, 3, 19, 0, 0, 0, DateTimeKind.Local), "su_kien,social,hoat_dong_gia_dinh", "Sinh hoạt cộng đồng cư dân tòa A", null },
                    { new Guid("22222222-2222-2222-2222-222222222222"), "A", new DateTime(2025, 12, 3, 5, 34, 49, 258, DateTimeKind.Utc).AddTicks(6603), "Trò chơi và vẽ tranh cho trẻ em.", new DateTime(2025, 12, 3, 18, 0, 0, 0, DateTimeKind.Local), 5, false, new DateTime(2025, 12, 3, 16, 0, 0, 0, DateTimeKind.Local), "su_kien,tre_em,hoat_dong_gia_dinh", "Hoạt động thiếu nhi tầng 5 tòa A", null }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_Code",
                table: "Activities",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Bills_ResidentProfileId_Type_DueDate",
                table: "Bills",
                columns: new[] { "ResidentProfileId", "Type", "DueDate" });

            migrationBuilder.CreateIndex(
                name: "IX_CommunityEvents_Building_Floor_StartTime",
                table: "CommunityEvents",
                columns: new[] { "Building", "Floor", "StartTime" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Activities");

            migrationBuilder.DropTable(
                name: "Bills");

            migrationBuilder.DropTable(
                name: "CommunityEvents");

            migrationBuilder.DropColumn(
                name: "Age",
                table: "ResidentProfiles");

            migrationBuilder.DropColumn(
                name: "Building",
                table: "ResidentProfiles");

            migrationBuilder.DropColumn(
                name: "Floor",
                table: "ResidentProfiles");

            migrationBuilder.DropColumn(
                name: "LifeStyle",
                table: "ResidentProfiles");

            migrationBuilder.DropColumn(
                name: "PreferredActivitiesJson",
                table: "ResidentProfiles");
        }
    }
}
