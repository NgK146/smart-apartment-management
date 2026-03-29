using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ICitizen.Migrations
{
    /// <inheritdoc />
    public partial class LockerManagementSystem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LockerTransactions_LockerBoxes_LockerBoxId",
                table: "LockerTransactions");

            migrationBuilder.DropTable(
                name: "LockerBoxes");

            migrationBuilder.DropColumn(
                name: "DepositedAtUtc",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "OtpCode",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "RecipientUserId",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "SenderUserId",
                table: "LockerTransactions");

            migrationBuilder.RenameColumn(
                name: "PickedAtUtc",
                table: "LockerTransactions",
                newName: "PickupTokenExpireAt");

            migrationBuilder.RenameColumn(
                name: "LockerBoxId",
                table: "LockerTransactions",
                newName: "CompartmentId");

            migrationBuilder.RenameColumn(
                name: "ExpireAtUtc",
                table: "LockerTransactions",
                newName: "PickupTime");

            migrationBuilder.RenameIndex(
                name: "IX_LockerTransactions_LockerBoxId",
                table: "LockerTransactions",
                newName: "IX_LockerTransactions_CompartmentId");

            migrationBuilder.AddColumn<Guid>(
                name: "ApartmentId",
                table: "LockerTransactions",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<DateTime>(
                name: "DropTime",
                table: "LockerTransactions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DropTokenHash",
                table: "LockerTransactions",
                type: "nvarchar(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "LockerTransactions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PickupTokenHash",
                table: "LockerTransactions",
                type: "nvarchar(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SecurityUserId",
                table: "LockerTransactions",
                type: "nvarchar(450)",
                maxLength: 450,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Code",
                table: "Lockers",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "AuditLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TransactionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Action = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    ByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    At = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AuditLogs_LockerTransactions_TransactionId",
                        column: x => x.TransactionId,
                        principalTable: "LockerTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Compartments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    LockerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ApartmentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Compartments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Compartments_Apartments_ApartmentId",
                        column: x => x.ApartmentId,
                        principalTable: "Apartments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Compartments_Lockers_LockerId",
                        column: x => x.LockerId,
                        principalTable: "Lockers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111111"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 12, 5, 48, 53, 218, DateTimeKind.Utc).AddTicks(4597), new DateTime(2025, 12, 12, 21, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 12, 19, 0, 0, 0, DateTimeKind.Local) });

            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222222"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 12, 5, 48, 53, 218, DateTimeKind.Utc).AddTicks(4603), new DateTime(2025, 12, 12, 18, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 12, 16, 0, 0, 0, DateTimeKind.Local) });

            migrationBuilder.CreateIndex(
                name: "IX_LockerTransactions_ApartmentId",
                table: "LockerTransactions",
                column: "ApartmentId");

            migrationBuilder.CreateIndex(
                name: "IX_LockerTransactions_SecurityUserId",
                table: "LockerTransactions",
                column: "SecurityUserId");

            migrationBuilder.CreateIndex(
                name: "IX_LockerTransactions_Status",
                table: "LockerTransactions",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Lockers_Code",
                table: "Lockers",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_TransactionId",
                table: "AuditLogs",
                column: "TransactionId");

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogs_TransactionId_At",
                table: "AuditLogs",
                columns: new[] { "TransactionId", "At" });

            migrationBuilder.CreateIndex(
                name: "IX_Compartments_ApartmentId",
                table: "Compartments",
                column: "ApartmentId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Compartments_Code",
                table: "Compartments",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Compartments_LockerId",
                table: "Compartments",
                column: "LockerId");

            migrationBuilder.AddForeignKey(
                name: "FK_LockerTransactions_Apartments_ApartmentId",
                table: "LockerTransactions",
                column: "ApartmentId",
                principalTable: "Apartments",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_LockerTransactions_Compartments_CompartmentId",
                table: "LockerTransactions",
                column: "CompartmentId",
                principalTable: "Compartments",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LockerTransactions_Apartments_ApartmentId",
                table: "LockerTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_LockerTransactions_Compartments_CompartmentId",
                table: "LockerTransactions");

            migrationBuilder.DropTable(
                name: "AuditLogs");

            migrationBuilder.DropTable(
                name: "Compartments");

            migrationBuilder.DropIndex(
                name: "IX_LockerTransactions_ApartmentId",
                table: "LockerTransactions");

            migrationBuilder.DropIndex(
                name: "IX_LockerTransactions_SecurityUserId",
                table: "LockerTransactions");

            migrationBuilder.DropIndex(
                name: "IX_LockerTransactions_Status",
                table: "LockerTransactions");

            migrationBuilder.DropIndex(
                name: "IX_Lockers_Code",
                table: "Lockers");

            migrationBuilder.DropColumn(
                name: "ApartmentId",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "DropTime",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "DropTokenHash",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "PickupTokenHash",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "SecurityUserId",
                table: "LockerTransactions");

            migrationBuilder.DropColumn(
                name: "Code",
                table: "Lockers");

            migrationBuilder.RenameColumn(
                name: "PickupTokenExpireAt",
                table: "LockerTransactions",
                newName: "PickedAtUtc");

            migrationBuilder.RenameColumn(
                name: "PickupTime",
                table: "LockerTransactions",
                newName: "ExpireAtUtc");

            migrationBuilder.RenameColumn(
                name: "CompartmentId",
                table: "LockerTransactions",
                newName: "LockerBoxId");

            migrationBuilder.RenameIndex(
                name: "IX_LockerTransactions_CompartmentId",
                table: "LockerTransactions",
                newName: "IX_LockerTransactions_LockerBoxId");

            migrationBuilder.AddColumn<DateTime>(
                name: "DepositedAtUtc",
                table: "LockerTransactions",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "OtpCode",
                table: "LockerTransactions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RecipientUserId",
                table: "LockerTransactions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "SenderUserId",
                table: "LockerTransactions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "LockerBoxes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LockerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BoxNumber = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    Size = table.Column<int>(type: "int", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LockerBoxes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LockerBoxes_Lockers_LockerId",
                        column: x => x.LockerId,
                        principalTable: "Lockers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111111"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 5, 7, 33, 37, 452, DateTimeKind.Utc).AddTicks(7636), new DateTime(2025, 12, 5, 21, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 5, 19, 0, 0, 0, DateTimeKind.Local) });

            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222222"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 5, 7, 33, 37, 452, DateTimeKind.Utc).AddTicks(7641), new DateTime(2025, 12, 5, 18, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 5, 16, 0, 0, 0, DateTimeKind.Local) });

            migrationBuilder.CreateIndex(
                name: "IX_LockerBoxes_LockerId",
                table: "LockerBoxes",
                column: "LockerId");

            migrationBuilder.AddForeignKey(
                name: "FK_LockerTransactions_LockerBoxes_LockerBoxId",
                table: "LockerTransactions",
                column: "LockerBoxId",
                principalTable: "LockerBoxes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
