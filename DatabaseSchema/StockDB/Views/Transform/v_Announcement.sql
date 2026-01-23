-- View: [Transform].[v_Announcement]


CREATE view [Transform].[v_Announcement]
as
select 
	ASXCode,
	AnnDateTime,
	ObservationDate,
	MarketSensitiveIndicator,
	AnnDescr
from ArchiveDB.[StockData].[Announcement]
union 
select 
	ASXCode,
	AnnDateTime,
	ObservationDate,
	MarketSensitiveIndicator,
	AnnDescr
from [StockData].[Announcement]
