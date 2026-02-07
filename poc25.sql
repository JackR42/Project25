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

-- Drop existing objects if they exist
DROP VIEW IF EXISTS dbo.vPersonMoT;
DROP TABLE IF EXISTS dbo.MeansOfTransportation;
DROP TABLE IF EXISTS dbo.Person;
DROP TABLE IF EXISTS dbo.CriminalOffence;
GO

create table dbo.CriminalOffence (
    OffenceID int primary key
    , Summary varchar(100) not null
    , Descr varchar(500) null
    , CreateDate datetime not null
);
go
insert into dbo.CriminalOffence(OffenceID, Summary, Descr, CreateDate) values
    (1, 'Terrorism attack', 'Suspects left the crime scene driving very fast, more than 200 km/h', '2023-01-15')
    , (2, 'Money Laundering incident', 'Suspects driving around very slowly', '2025-02-20')
    , (3, 'Child Abuse case', 'Suspects walked around exploring the area','2026-02-05')
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
create table dbo.MeansOfTransportation(
    MotID int primary key
    , VIN varchar(100) not null
    , Descr varchar(500) null
    , ImageURL varchar(500) null
    , ImageBlob varbinary(MAX) null
    , ImageEmbedding vector(1536) null
    , PersonID int null
    , foreign key (PersonID) references dbo.Person(PersonID)
);
GO
 
insert into dbo.MeansOfTransportation(MotID, VIN, Descr, ImageURL, ImageBlob, PersonID) values
    (1, '3-ZBZ-54', 'Car1', NULL, NULL, 1)    -- Maserati GranCabrio
    , (2, 'XF-FG-78', 'Car2', NULL, NULL, 2)  -- Porsche 911 Turbo
    , (3, 'SX-610-X', 'Car3', NULL, NULL, 3)  -- Mini Cooper One
    , (4, 'RO-123-45', 'Car4', NULL, NULL, 4)  -- Dacia Logan
;
GO

create view vPersonMoT AS
select p.PersonID, FirstName, LastName, VIN, Descr
from Person p
join MeansOfTransportation mot on p.PersonID = mot.PersonID;
GO
-- select * from dbo.vPersonMoT
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
DROP PROCEDURE IF EXISTS dbo.LoadImageFromFile;
GO
CREATE PROCEDURE dbo.LoadImageFromFile
    @MotID int,
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
        
        -- Update the MeansOfTransportation table
        UPDATE dbo.MeansOfTransportation
        SET ImageBlob = @ImageData,
            ImageURL = @FilePath
        WHERE MotID = @MotID;
        
        IF @@ROWCOUNT > 0
            PRINT 'Image successfully loaded for MotID ' + CAST(@MotID AS VARCHAR(10)) + 
                  ' from ' + @FilePath + ' (' + CAST(DATALENGTH(@ImageData) AS VARCHAR(20)) + ' bytes)';
        ELSE
            RAISERROR('MotID %d not found', 16, 1, @MotID);
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Failed to load image: %s', 16, 1, @ErrorMessage);
    END CATCH
END
GO

EXEC dbo.LoadImageFromFile @MotID = 1, @FilePath = '/workspaces/Project25/Images/Car1.jpg';
EXEC dbo.LoadImageFromFile @MotID = 2, @FilePath = '/workspaces/Project25/Images/Car2.jpg';
EXEC dbo.LoadImageFromFile @MotID = 3, @FilePath = '/workspaces/Project25/Images/Car3.jpg';
EXEC dbo.LoadImageFromFile @MotID = 4, @FilePath = '/workspaces/Project25/Images/Car4.jpg';

GO

-- Verify images were loaded
SELECT MotID, VIN, Descr, ImageURL, 
       CASE WHEN ImageBlob IS NULL THEN 'No Image' 
            ELSE 'Image Loaded (' + CAST(DATALENGTH(ImageBlob) AS VARCHAR(20)) + ' bytes)' 
       END AS ImageStatus,
       CASE WHEN ImageEmbedding IS NULL THEN 'No Embedding' 
            ELSE 'Image Embedding (' + CAST(DATALENGTH(ImageEmbedding) AS VARCHAR(20)) + ' bytes)' 
       END AS EmbeddingStatus
FROM dbo.MeansOfTransportation
ORDER BY MotID;
GO

-- Display actual images (will render in Azure Data Studio / SSMS)
SELECT 
    MotID,
    VIN,
    Descr,
    ImageURL,
    ImageBlob AS Image,
    DATALENGTH(ImageBlob) AS ImageSizeBytes
FROM dbo.MeansOfTransportation
WHERE ImageBlob IS NOT NULL
ORDER BY MotID;
GO



-- Stored procedure to generate embedding summary
CREATE OR ALTER PROCEDURE dbo.GetEmbeddingSummary
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        MotID,
        VIN,
        Descr,
        CASE 
            WHEN ImageEmbedding IS NULL THEN 'No Embedding'
            ELSE 'Image Embedding (' + CAST(DATALENGTH(ImageEmbedding) AS VARCHAR(20)) + ' bytes)'
        END AS ImageEmbeddingStatus,
        p.FirstName + ' ' + p.LastName AS Owner
    FROM dbo.MeansOfTransportation m
    LEFT JOIN dbo.Person p ON m.PersonID = p.PersonID
    ORDER BY MotID;
END
GO

-- Display embedding summary
PRINT '';
PRINT '============================================================================';
PRINT 'IMAGE EMBEDDING SUMMARY';
PRINT '============================================================================';
EXEC dbo.GetEmbeddingSummary;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Database setup complete!';
PRINT '============================================================================';
GO
