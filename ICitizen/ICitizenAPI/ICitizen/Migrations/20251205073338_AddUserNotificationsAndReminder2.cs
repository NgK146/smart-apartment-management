using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ICitizen.Migrations
{
    /// <inheritdoc />
    public partial class AddUserNotificationsAndReminder2 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("11111111-1111-1111-1111-111111111111"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 3, 5, 34, 49, 258, DateTimeKind.Utc).AddTicks(6598), new DateTime(2025, 12, 3, 21, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 3, 19, 0, 0, 0, DateTimeKind.Local) });

            migrationBuilder.UpdateData(
                table: "CommunityEvents",
                keyColumn: "Id",
                keyValue: new Guid("22222222-2222-2222-2222-222222222222"),
                columns: new[] { "CreatedAtUtc", "EndTime", "StartTime" },
                values: new object[] { new DateTime(2025, 12, 3, 5, 34, 49, 258, DateTimeKind.Utc).AddTicks(6603), new DateTime(2025, 12, 3, 18, 0, 0, 0, DateTimeKind.Local), new DateTime(2025, 12, 3, 16, 0, 0, 0, DateTimeKind.Local) });
        }
    }
}
