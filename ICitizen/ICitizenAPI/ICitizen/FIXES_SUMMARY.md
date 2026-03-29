# Tóm tắt các sửa lỗi đã thực hiện

## 1. Lỗi SQL: Invalid column name 'Type' trong ReportsController

**Vấn đề:** Query trong `ReportsController.Overview()` cố gắng select cột `Type` từ bảng `Invoices` nhưng cột này chưa tồn tại trong database.

**Giải pháp đã áp dụng:**
- Sửa query ở dòng 75 để chỉ select `Id` thay vì toàn bộ Invoice entity
- Tạo script SQL (`add_invoice_type_column.sql`) để thêm cột Type vào database

**Cần làm:**
1. Dừng ứng dụng (nếu đang chạy)
2. Chạy migration: `dotnet ef database update` 
   HOẶC chạy script SQL: `add_invoice_type_column.sql` trực tiếp trên SQL Server
3. Khởi động lại ứng dụng

## 2. Cảnh báo: Decimal properties thiếu precision

**Vấn đề:** 
- `AmenityBooking.Price` thiếu cấu hình precision
- `Apartment.AreaM2` thiếu cấu hình precision

**Giải pháp đã áp dụng:**
- Thêm `HasPrecision(18, 2)` cho cả hai properties trong `ApplicationDbContext.OnModelCreating()`

## 3. Cảnh báo: CommunityPost.ImageUrls thiếu ValueComparer

**Vấn đề:** Property `ImageUrls` (List<string>) có ValueConverter nhưng thiếu ValueComparer.

**Giải pháp đã áp dụng:**
- Thêm ValueComparer cho `ImageUrls` để EF Core có thể so sánh collection elements đúng cách

## Các file đã sửa:

1. `ICitizen/ICitizenAPI/ICitizen/Controllers/ReportsController.cs`
   - Sửa query để tránh select cột Type chưa tồn tại

2. `ICitizen/ICitizenAPI/ICitizen/Data/ApplicationDbContext.cs`
   - Thêm HasPrecision cho AmenityBooking.Price
   - Thêm HasPrecision cho Apartment.AreaM2
   - Thêm ValueComparer cho CommunityPost.ImageUrls

3. `ICitizen/ICitizenAPI/ICitizen/add_invoice_type_column.sql` (mới tạo)
   - Script SQL để thêm cột Type vào bảng Invoices

## Các vấn đề khác cần lưu ý:

### Các query có thể gặp vấn đề tương tự (sau khi chạy migration sẽ OK):

1. **PaymentsController.cs** - Các query Include Invoice:
   - Dòng 33, 47, 131, 185, 230: `.Include(x => x.Invoice)`
   - Sau khi migration chạy, các query này sẽ hoạt động bình thường

2. **InvoicesController.cs** - Các query select Invoice:
   - Dòng 29, 41, 81, 91, 110, 169, 199, 210, 238: Các query select Invoice
   - Sau khi migration chạy, các query này sẽ hoạt động bình thường

3. **BillingController.cs**:
   - Dòng 95: `AnyAsync` với điều kiện `i.Type == type` - sẽ hoạt động sau khi migration

## Hướng dẫn chạy migration:

### Cách 1: Sử dụng EF Core Migration (Khuyến nghị)
```bash
cd ICitizen\ICitizenAPI\ICitizen
dotnet ef database update
```

### Cách 2: Chạy SQL Script trực tiếp
1. Mở SQL Server Management Studio hoặc Azure Data Studio
2. Kết nối đến database
3. Mở file `add_invoice_type_column.sql`
4. Execute script

### Cách 3: Nếu ứng dụng đang chạy
1. Dừng ứng dụng (Ctrl+C trong terminal hoặc stop trong Visual Studio)
2. Chạy migration hoặc SQL script
3. Khởi động lại ứng dụng

## Lưu ý:
- Sau khi chạy migration, tất cả các query Invoice sẽ hoạt động bình thường
- Các cảnh báo về decimal precision và ValueComparer đã được sửa và sẽ không còn xuất hiện sau khi rebuild























