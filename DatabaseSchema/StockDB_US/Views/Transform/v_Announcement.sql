-- View: [Transform].[v_Announcement]

create view Transform.v_Announcement
as
select 
	ASXCode,
	AnnDateTime,
	cast(AnndateTime as date) as ObservationDate,
	MarketSensitiveIndicator,
	AnnDescr
from [ArchiveDB].[StockData].[Announcement]
union 
select 
	ASXCode,
	AnnDateTime,
	cast(AnndateTime as date) as ObservationDate,
	MarketSensitiveIndicator,
	AnnDescr
from [StockData].[Announcement]
