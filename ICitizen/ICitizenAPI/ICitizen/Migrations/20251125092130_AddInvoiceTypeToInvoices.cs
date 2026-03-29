using ICitizen.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ICitizen.Migrations
{
    [DbContext(typeof(ApplicationDbContext))]
    [Migration("20251125092130_AddInvoiceTypeToInvoices")]
    public partial class AddInvoiceTypeToInvoices : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Kiểm tra xem cột Type đã tồn tại chưa
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Invoices]') AND name = 'Type')
                BEGIN
                    ALTER TABLE [dbo].[Invoices] ADD [Type] int NOT NULL DEFAULT 0;
                END
            ");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Type",
                table: "Invoices");
        }
    }
}











