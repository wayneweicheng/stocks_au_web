-- View: [StockData].[v_OptionDelayedQuote_V2_Include_Archive]








create view [StockData].[v_OptionDelayedQuote_V2_Include_Archive]
as
	select *
	from [StockData].[OptionDelayedQuote_V2]
	union all
	select *		
	from ArchiveDB_US.[StockData].[OptionDelayedQuote_V2] as a
	where not exists
	(
		select 1
		from [StockData].[OptionDelayedQuote_V2]
		where ASXCode = a.ASXCode
		and ObservationDate = a.ObservationDate
	)
