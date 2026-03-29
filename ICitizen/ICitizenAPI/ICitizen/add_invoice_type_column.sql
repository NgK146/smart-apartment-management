-- Script để thêm cột Type vào bảng Invoices
-- Chạy script này trực tiếp trên SQL Server nếu migration chưa được chạy

IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[Invoices]') 
    AND name = 'Type'
)
BEGIN
    ALTER TABLE [dbo].[Invoices]
    ADD [Type] INT NOT NULL DEFAULT 0;
    
    PRINT 'Column Type added successfully to Invoices table';
END
ELSE
BEGIN
    PRINT 'Column Type already exists in Invoices table';
END























