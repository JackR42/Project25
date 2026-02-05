use master
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'POC25')
BEGIN
    ALTER DATABASE POC25 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE POC25;
END
GO
create database POC25;
go
use POC25;
go
create table dbo.Offence (
    OffenceID int primary key
    , Summary varchar(100) not null
    , Description varchar(1000) not null
    , OffenceDate datetime not null
);
go
insert into dbo.Offence(OffenceID, Summary, Description, OffenceDate) values
    (1, 'Terrorism attack', 'Suspects drove away very fast more than 200 km/h', '2023-01-15')
    , (2, 'Money Laundering incident', 'Suspects drove away slowly', '2025-02-20')
    , (3, 'Child Abuse case', 'Suspects walked away','2026-02-05')
;
GO
create table dbo.Person(
    PersonID int primary key
    , Firstname varchar(100)
    , Lastname varchar(100)
    , DoB DATETIME
);
GO
insert into dbo.Person(PersonID, Firstname, Lastname, DoB) VALUES
    (1, 'Jack', 'Johnson', '2000-01-01')
    , (2, 'Jane', 'Doe', '2002-11-21')
    , (3, 'Bad', 'Guy', '2001-09-11')
    , (4, 'Good', 'Guy', '1970-01-01')
;
GO

create table dbo.Car(
    CarID int primary key
    , LicensePlate varchar(100) not null
    , ImageURL varchar(500) null
    , ImageBlob varbinary(MAX) null
    , PersonID int null
    , foreign key (PersonID) references dbo.Person(PersonID)
);
GO
 
insert into dbo.Car(CarID, LicensePlate, ImageURL, ImageBlob, PersonID) values
    (1, '3-ZBZ-54', NULL, NULL, 1)    -- Maserati GranCabrio
    , (2, 'XF-FG-78', NULL, NULL, 2)  -- Porsche 911 Turbo
    , (3, 'SX-610-X', NULL, NULL, 3)  -- Mini Cooper One
    , (4, 'RO-12-345', NULL, NULL, 4)  -- Dacia Logan
;
GO

create view vPersonCar AS
select p.PersonID, FirstName, LastName, LicensePlate 
from Person p
join Car c on p.PersonID = c.PersonID;
GO
select * from dbo.vPersonCar
GO

-- Note: OPENROWSET BULK requires 'Ad Hoc Distributed Queries' to be enabled
-- This may not be available in all SQL Server editions (e.g., Azure SQL, Linux)
-- Try to enable it, but handle the error if not supported

BEGIN TRY
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
    RECONFIGURE;
    PRINT 'Ad Hoc Distributed Queries enabled successfully';
END TRY
BEGIN CATCH
    PRINT 'Warning: Ad Hoc Distributed Queries could not be enabled. This feature may not be available in your SQL Server edition.';
    PRINT 'Alternative: Use the Python script (load_images.py) to load images instead.';
END CATCH
GO

-- Stored procedure to load image from file
CREATE PROCEDURE dbo.LoadImageFromFile
    @CarID int,
    @FilePath varchar(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ImageData varbinary(MAX);
    DECLARE @SQL nvarchar(MAX);
    
    BEGIN TRY
        -- Build dynamic SQL to load file using OPENROWSET
        SET @SQL = N'SELECT @ImageData = BulkColumn 
                     FROM OPENROWSET(BULK ''' + @FilePath + ''', SINGLE_BLOB) AS ImageFile';
        
        -- Execute and get the binary data
        EXEC sp_executesql @SQL, N'@ImageData varbinary(MAX) OUTPUT', @ImageData OUTPUT;
        
        -- Update the Car table
        UPDATE dbo.Car
        SET ImageBlob = @ImageData,
            ImageURL = @FilePath
        WHERE CarID = @CarID;
        
        IF @@ROWCOUNT > 0
            PRINT 'Image successfully loaded for CarID ' + CAST(@CarID AS VARCHAR(10)) + 
                  ' from ' + @FilePath + ' (' + CAST(DATALENGTH(@ImageData) AS VARCHAR(20)) + ' bytes)';
        ELSE
            RAISERROR('CarID %d not found', 16, 1, @CarID);
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Failed to load image: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

EXEC dbo.LoadImageFromFile @CarID = 1, @FilePath = '/workspaces/Project25/Images/Car1.jpg';
EXEC dbo.LoadImageFromFile @CarID = 2, @FilePath = '/workspaces/Project25/Images/Car2.jpg';
EXEC dbo.LoadImageFromFile @CarID = 3, @FilePath = '/workspaces/Project25/Images/Car3.jpg';
EXEC dbo.LoadImageFromFile @CarID = 4, @FilePath = '/workspaces/Project25/Images/Car4.jpg';

GO

-- Verify images were loaded
SELECT CarID, LicensePlate, ImageURL, 
       CASE WHEN ImageBlob IS NULL THEN 'No Image' 
            ELSE 'Image Loaded (' + CAST(DATALENGTH(ImageBlob) AS VARCHAR(20)) + ' bytes)' 
       END AS ImageStatus
FROM dbo.Car
ORDER BY CarID;
GO

-- Display actual images (will render in Azure Data Studio / SSMS)
SELECT 
    CarID,
    LicensePlate,
    ImageURL,
    ImageBlob AS Image,
    DATALENGTH(ImageBlob) AS ImageSizeBytes
FROM dbo.Car
WHERE ImageBlob IS NOT NULL
ORDER BY CarID;
GO
