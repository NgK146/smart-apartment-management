using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ICitizen.Migrations
{
    /// <inheritdoc />
    public partial class AddVisitorAccess : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "VisitorAccesses",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ResidentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ApartmentCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    VisitorName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    VisitorPhone = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    VisitorEmail = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    VisitDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    VisitTime = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true),
                    Purpose = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    QrCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    QrCodeUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CheckedInAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CheckedOutAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VisitorAccesses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VisitorAccesses_ResidentProfiles_ResidentId",
                        column: x => x.ResidentId,
                        principalTable: "ResidentProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VisitorAccesses_QrCode",
                table: "VisitorAccesses",
                column: "QrCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VisitorAccesses_ResidentId",
                table: "VisitorAccesses",
                column: "ResidentId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VisitorAccesses");
        }
    }
}
