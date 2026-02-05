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
    , Descr varchar(100) not null
    , OffenceDate datetime not null
);
go
insert into dbo.Offence(OffenceID, Descr, OffenceDate) values
(1, 'Terrorism attack', '2023-01-15'),
(2, 'Money Laundering incident', '2025-02-20'),
(3, 'Child Abuse case', '2026-02-05');
GO
create table dbo.Person(
    PersonID int primary key
    , Firstname varchar(100)
    , Lastname varchar(100)
    , DoB DATETIME
);
GO
insert into dbo.Person(PersonID, Firstname, Lastname, DoB) VALUES
(1, 'Jack', 'Johnson', '2000-01-01'),
(2, 'Jane', 'Doe', '2002-11-21'),
(3, 'Bad', 'Guy', '2001-09-11');
GO
create table dbo.Involved(
    PersonID int not null
    , OffenceID int not null
    , Involvement varchar(50)
    , InvolvedDate datetime
    , primary key (PersonID, OffenceID)
    , foreign key (PersonID) references dbo.Person(PersonID)
    , foreign key (OffenceID) references dbo.Offence(OffenceID)
);
GO
insert into dbo.Involved(PersonID, OffenceID, Involvement, InvolvedDate) values
(1, 1, 'Suspect', '2023-01-15'),
(2, 2, 'Witness', '2025-02-20'),
(3, 1, 'Perpetrator', '2023-01-15'),
(3, 3, 'Victim', '2026-02-05');
GO
create view dbo.vOffence AS 
select o.Descr, Person = p.Firstname+' '+ p.Lastname, DoB= cast(p.DoB as Date), i.Involvement, OffenceDate = cast(o.offenceDate as date   )
from Person p
join Involved i on p.PersonID = i.PersonID
join Offence o on i.OffenceID = o.OffenceID;
GO
select * from dbo.vOffence;
GO
create table dbo.MoT(
    MoTID int primary key
    , MoTType varchar(50) not null
    , MoTRegistration varchar(50) 
);
GO

insert into dbo.MoT(MoTID, MoTType, MoTRegistration) values
(1, 'Maserati Gran Cabrio', 'AB-123-C'),
(2, 'Porsche 911 Turbo', '12-EF-34'),
(3, 'Mini Cooper One', 'GH-567-I');
GO
create table MOT_Owner(
    MoTID int not null
    , PersonID int not null
    , OwnershipDate datetime not null
    , primary key (MoTID, PersonID)
    , foreign key (MoTID) references dbo.MoT(MoTID)
    , foreign key (PersonID) references dbo.Person(PersonID)
);
insert into MOT_Owner(MoTID, PersonID, OwnershipDate) values
(1, 1, '2022-05-01'),
(2, 2, '2023-03-15'),
(3, 3, '2024-07-20');
GO
create table dbo.MultiMedia(
    MultiMediaID int primary key,
    Descr varchar(100) not null,
    MediaType varchar(50),
    MediaPath varchar(255),
    Blob varbinary(max) 
);
GO

insert into dbo.MultiMedia(MultiMediaID, Descr, MediaType, MediaPath) values
(1, 'Jack Johnson Photo', 'Photo', '/images/jack_johnson_1.jpg'),
(2, 'Jack Johnson Interview', 'Video', '/videos/jack_johnson_interview.mp4'),
(3, 'Jane Doe Photo', 'Photo', '/images/jane_doe_1.jpg'),
(4, 'Bad Guy Statement', 'Audio', '/audio/bad_guy_statement.mp4');
GO

create table MOT_MultiMedia(
    MoTID int not null
    , MultiMediaID int not null
    , primary key (MoTID, MultiMediaID)
    , foreign key (MoTID) references dbo.MoT(MoTID)
    , foreign key (MultiMediaID) references dbo.MultiMedia(MultiMediaID)
);
insert into MOT_MultiMedia(MoTID, MultiMediaID) values
(1, 1),
(1, 2),
(2, 3),
(3, 4);
select *
from dbo.Person p
join MOT_Owner mo on p.PersonID = mo.PersonID
join dbo.MoT m on mo.MoTID = m.MoTID
join dbo.MOT_MultiMedia ON m.MoTID = dbo.MOT_MultiMedia.MoTID
join dbo.MultiMedia mm on dbo.MOT_MultiMedia.MultiMediaID = mm.MultiMediaID;
GO
