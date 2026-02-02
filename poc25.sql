use master
GO
drop database if exists POC25;
go
create database POC25;
go
use POC25;
go
create table dbo.Offence(
    OffenceID int primary key
    , OffenceDescr varchar(100) not null
    , offenceDate datetime not null
);
go
insert into dbo.Offence(OffenceID, OffenceDescr, offenceDate) values
(1, 'Theft', '2023-01-15 10:30:00'),
(2, 'Assault', '2023-02-20 14:45:00'),
(3, 'Burglary', '2023-03-05 09:15:00');
GO
select * from dbo.Offence;
go


