-- Locker Management System - Seed Data Script
-- Run this to create test data for lockers, compartments, and link them to apartments

-- Step 1: Create a locker
DECLARE @LockerId UNIQUEIDENTIFIER = NEWID();
DECLARE @Now DATETIME2 = GETUTCDATE();

INSERT INTO Lockers (Id, Code, Name, Location, CreatedAtUtc, IsDeleted)
VALUES (@LockerId, 'L1', 'Main Lobby Locker', 'Building A - Ground Floor', @Now, 0);

-- Step 2: Get first 10 apartments for testing
DECLARE @Apartments TABLE (Id UNIQUEIDENTIFIER, Code NVARCHAR(20), RowNum INT);

INSERT INTO @Apartments (Id, Code, RowNum)
SELECT TOP 10 Id, Code, ROW_NUMBER() OVER (ORDER BY Code)
FROM Apartments
WHERE NOT EXISTS (SELECT 1 FROM Compartments WHERE ApartmentId = Apartments.Id)
ORDER BY Code;

-- Step 3: Create compartments for each apartment
INSERT INTO Compartments (Id, Code, LockerId, ApartmentId, Status, CreatedAtUtc, IsDeleted)
SELECT 
    NEWID(),
    'L1-C' + RIGHT('00' + CAST(RowNum AS VARCHAR(2)), 2),  -- L1-C01, L1-C02, etc.
    @LockerId,
    Id,
    0,  -- Empty status
    @Now,
    0
FROM @Apartments;

-- Verify results
SELECT 
    l.Code AS LockerCode,
    c.Code AS CompartmentCode,
    a.Code AS ApartmentCode,
    c.Status
FROM Compartments c
INNER JOIN Lockers l ON c.LockerId = l.Id
INNER JOIN Apartments a ON c.ApartmentId = a.Id
ORDER BY c.Code;

PRINT 'Locker system seed data created successfully!';
PRINT 'Created 1 locker with compartments for the first 10 available apartments.';
