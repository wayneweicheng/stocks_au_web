-- Stored procedure: [DataMaintenance].[usp_ArchiveStockData]





CREATE PROCEDURE [DataMaintenance].[usp_ArchiveStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_ArchiveStockData.sql
Stored Procedure Name: usp_ArchiveStockData
Overview
-----------------
usp_ArchiveStockData

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2017-06-18
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_ArchiveStockData'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempArchivedAnnouncementID') is not null
			drop table #TempArchivedAnnouncementID
		
		select distinct AnnouncementID
		into #TempArchivedAnnouncementID
		from ArchiveDB_US.StockData.Announcement

		create clustered index idx_#TempArchivedAnnouncementID_announcementid on #TempArchivedAnnouncementID(AnnouncementID)

		if object_id(N'Tempdb.dbo.#TempAnnouncementID') is not null
			drop table #TempAnnouncementID
		
		select AnnouncementID
		into #TempAnnouncementID
		from StockData.Announcement as a
		where not exists
		(
			select 1
			from #TempArchivedAnnouncementID
			where AnnouncementID = a.AnnouncementID
		)
		and datediff(day, AnnDateTime, getdate()) > 180

		insert into ArchiveDB_US.StockData.Announcement
		(
			   [AnnouncementID]
			  ,[ASXCode]
			  ,[AnnRetriveDateTime]
			  ,[AnnDateTime]
			  ,[MarketSensitiveIndicator]
			  ,[AnnDescr]
			  ,[AnnURL]
			  ,[AnnContent]
			  ,[AnnNumPage]
			  ,[CreateDate]
			  ,ArchiveDate
		)
		select
			   a.[AnnouncementID]
			  ,[ASXCode]
			  ,[AnnRetriveDateTime]
			  ,[AnnDateTime]
			  ,[MarketSensitiveIndicator]
			  ,[AnnDescr]
			  ,[AnnURL]
			  ,[AnnContent]
			  ,[AnnNumPage]
			  ,[CreateDate]
			  ,getdate() as ArchiveDate
		from StockData.Announcement as a
		inner join #TempAnnouncementID as b
		on a.AnnouncementID = b.AnnouncementID

		insert into ArchiveDB_US.[StockData].[AnnouncementToken]
		(
			   [AnnouncementTokenID]
			  ,[AnnouncementID]
			  ,[Token]
			  ,[Cnt]
			  ,[CreateDate]
			  ,ArchiveDate
		)
		select
			   a.[AnnouncementTokenID]
			  ,a.[AnnouncementID]
			  ,[Token]
			  ,[Cnt]
			  ,[CreateDate]
			  ,getdate() as ArchiveDate
		from [StockData].[AnnouncementToken] as a
		inner join #TempAnnouncementID as b
		on a.AnnouncementID = b.AnnouncementID

		delete a
		from StockData.Announcement as a
		inner join ArchiveDB_US.StockData.Announcement as b
		on a.AnnouncementID = b.AnnouncementID

		delete a
		from StockData.AnnouncementToken as a
		inner join ArchiveDB_US.StockData.AnnouncementToken as b
		on a.AnnouncementID = b.AnnouncementID

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from StockData.PriceSummary as a
		where datediff(day, datefrom, getdate()) > 90

		declare @intRowNumber as int = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempPriceSummaryBatch') is not null
				drop table #TempPriceSummaryBatch

			select top 10000 *
			into #TempPriceSummaryBatch
			from #TempPriceSummary

			--insert into [Archive].[PriceSummaryHistory]
			--select *
			--from #TempPriceSummaryBatch

			delete a
			from StockData.PriceSummary as a
			inner join #TempPriceSummaryBatch as b
			on a.PriceSummaryID = b.PriceSummaryID

			delete a
			from #TempPriceSummary as a
			inner join #TempPriceSummaryBatch as b
			on a.PriceSummaryID = b.PriceSummaryID

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		select *
		into #TempOptionBidAsk
		from StockData.OptionBidAsk as a with(nolock)
		where ObservationDateLocal < dateadd(day, -8, getdate())

		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionBidAskBatch') is not null
				drop table #TempOptionBidAskBatch

			select top 500000 *
			into #TempOptionBidAskBatch
			from #TempOptionBidAsk

			delete a
			from StockData.OptionBidAsk as a
			inner join #TempOptionBidAskBatch as b
			on a.OptionBidAskID = b.OptionBidAskID

			delete a
			from #TempOptionBidAsk as a
			inner join #TempOptionBidAskBatch as b
			on a.OptionBidAskID = b.OptionBidAskID

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		select *
		into #TempOptionTrade
		from StockData.OptionTrade as a
		where datediff(day, SaleTime, getdate()) > 120

		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionTradeBatch') is not null
				drop table #TempOptionTradeBatch

			select top 500000 *
			into #TempOptionTradeBatch
			from #TempOptionTrade

			delete a
			from StockData.OptionTrade as a
			inner join #TempOptionTradeBatch as b
			on a.OptionTradeID = b.OptionTradeID

			delete a
			from #TempOptionTrade as a
			inner join #TempOptionTradeBatch as b
			on a.OptionTradeID = b.OptionTradeID

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		--declare @intRowNumber as int = 1

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteHistory') is not null
			drop table #TempOptionDelayedQuoteHistory

		select *
		into #TempOptionDelayedQuoteHistory
		from StockData.OptionDelayedQuoteHistory as a
		where datediff(day, CreateDate, getdate()) > 10

		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteHistoryBatch') is not null
				drop table #TempOptionDelayedQuoteHistoryBatch

			select top 500000 *
			into #TempOptionDelayedQuoteHistoryBatch
			from #TempOptionDelayedQuoteHistory

			delete a
			from StockData.OptionDelayedQuoteHistory as a
			inner join #TempOptionDelayedQuoteHistoryBatch as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			delete a
			from #TempOptionDelayedQuoteHistory as a
			inner join #TempOptionDelayedQuoteHistoryBatch as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		--declare @intRowNumber as int = 1

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteHistory_V2') is not null
			drop table #TempOptionDelayedQuoteHistory_V2

		select *
		into #TempOptionDelayedQuoteHistory_V2
		from StockData.OptionDelayedQuoteHistory_V2 as a
		where datediff(day, CreateDate, getdate()) > 10

		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteHistoryBatch_V2') is not null
				drop table #TempOptionDelayedQuoteHistoryBatch_V2

			select top 500000 *
			into #TempOptionDelayedQuoteHistoryBatch_V2
			from #TempOptionDelayedQuoteHistory_V2

			delete a
			from StockData.OptionDelayedQuoteHistory_V2 as a
			inner join #TempOptionDelayedQuoteHistoryBatch_V2 as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			delete a
			from #TempOptionDelayedQuoteHistory_V2 as a
			inner join #TempOptionDelayedQuoteHistoryBatch_V2 as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_V2') is not null
			drop table #TempOptionDelayedQuote_V2

		select *
		into #TempOptionDelayedQuote_V2
		from StockData.OptionDelayedQuote_V2 as a
		where 
		(
			(datediff(day, CreateDate, getdate()) > 20 and ASXCode not in ('SPXW.US', 'SPX.US', 'SPY.US', 'QQQ.US', 'GDX.US', 'TLT.US', 'OIH.US', 'UVXY.US', 'UVIX.US'))
			or
			(datediff(day, CreateDate, getdate()) > 180 and ASXCode in ('SPXW.US', 'SPX.US', 'SPY.US', 'QQQ.US', 'GDX.US', 'TLT.US', 'OIH.US', 'UVXY.US', 'UVIX.US'))			
		)

		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteBatch_V2') is not null
				drop table #TempOptionDelayedQuoteBatch_V2

			select top 500000 *
			into #TempOptionDelayedQuoteBatch_V2
			from #TempOptionDelayedQuote_V2

			insert into ArchiveDB_US.[StockData].[OptionDelayedQuote_V2]
			select *
			from #TempOptionDelayedQuoteBatch_V2
			where ASXCode not in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SLV.US', 'GLD.US', 'IBIT.US', 'GDX.US', 'VXX.US', 'SVIX.US', 'SPX.US', 'TLT.US', 'UVXY.US')

			insert into ArchiveDB_US.[StockData].[OptionDelayedQuoteCore_V2]
			select *
			from #TempOptionDelayedQuoteBatch_V2
			where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SLV.US', 'GLD.US', 'IBIT.US', 'GDX.US', 'VXX.US', 'SVIX.US', 'SPX.US', 'TLT.US', 'UVXY.US')

			delete a
			from StockData.OptionDelayedQuote_V2 as a
			inner join #TempOptionDelayedQuoteBatch_V2 as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			delete a
			from #TempOptionDelayedQuote_V2 as a
			inner join #TempOptionDelayedQuoteBatch_V2 as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote') is not null
			drop table #TempOptionDelayedQuote

		select *
		into #TempOptionDelayedQuote
		from StockData.OptionDelayedQuote as a
		where 
		(
			(datediff(day, CreateDate, getdate()) > 10 and ASXCode not in ('SPXW.US', 'SPX.US', 'SPY.US', 'QQQ.US', 'GDX.US', 'TLT.US', 'OIH.US'))
			or
			(datediff(day, CreateDate, getdate()) > 180 and ASXCode in ('SPXW.US', 'SPX.US', 'SPY.US', 'QQQ.US', 'GDX.US', 'TLT.US', 'OIH.US'))			
		)
		--declare @intRowNumber as int = 1

		select @intRowNumber = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempOptionDelayedQuoteBatch') is not null
				drop table #TempOptionDelayedQuoteBatch

			select top 500000 *
			into #TempOptionDelayedQuoteBatch
			from #TempOptionDelayedQuote

			insert into ArchiveDB_US.[StockData].[OptionDelayedQuote]
			select *
			from #TempOptionDelayedQuoteBatch

			delete a
			from StockData.OptionDelayedQuote as a
			inner join #TempOptionDelayedQuoteBatch as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			delete a
			from #TempOptionDelayedQuote as a
			inner join #TempOptionDelayedQuoteBatch as b
			on a.OptionSymbol = b.OptionSymbol
			and a.CreateDate = b.CreateDate

			set @intRowNumber = @@rowcount

			print @intRowNumber

		end


	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
