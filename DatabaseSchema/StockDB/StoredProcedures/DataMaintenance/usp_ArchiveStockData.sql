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
		from ArchiveDB.StockData.Announcement

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

		insert into ArchiveDB.StockData.Announcement
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
			  ,ObservationDate
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
			  ,ObservationDate
		from StockData.Announcement as a
		inner join #TempAnnouncementID as b
		on a.AnnouncementID = b.AnnouncementID

		insert into ArchiveDB.[StockData].[AnnouncementToken]
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
		inner join ArchiveDB.StockData.Announcement as b
		on a.AnnouncementID = b.AnnouncementID

		delete a
		from StockData.AnnouncementToken as a
		inner join ArchiveDB.StockData.AnnouncementToken as b
		on a.AnnouncementID = b.AnnouncementID

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from StockData.PriceSummary as a
		where datediff(day, datefrom, getdate()) > 180

		declare @intRowNumber as int = 1

		while @intRowNumber > 0
		begin
			if object_id(N'Tempdb.dbo.#TempPriceSummaryBatch') is not null
				drop table #TempPriceSummaryBatch

			select top 10000 *
			into #TempPriceSummaryBatch
			from #TempPriceSummary

			insert into [Archive].[PriceSummaryHistory]
			select *
			from #TempPriceSummaryBatch

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

		declare @dtMaxPriceHistoryDate as date
		select @dtMaxPriceHistoryDate = max(ObservationDate)
		from
		(
			select ObservationDate
			from StockData.PriceHistory
			group by ObservationDate
			having count(*) > 1000
		) as a
		
		if @dtMaxPriceHistoryDate > dateadd(day, -20, getdate()) 
		begin
			delete a
			from StockData.BrokerReport as a
			where 1 = 1
			and not exists
			(
				select 1
				from StockData.PriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate > dateadd(day, -60, getdate()) 
				and Volume > 0
			)
		end

		if object_id(N'Tempdb.dbo.#TempBrokerReportToArchive') is not null
			drop table #TempBrokerReportToArchive

		select ASXCode, ObservationDate
		into #TempBrokerReportToArchive
		from [StockData].[BrokerReport]
		where ObservationDate < dateadd(day, -365, getdate())

		insert into ArchiveDB.[StockData].[BrokerReport]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[BrokerCode]
		  ,[Symbol]
		  ,[BuyValue]
		  ,[SellValue]
		  ,[NetValue]
		  ,[TotalValue]
		  ,[BuyVolume]
		  ,[SellVolume]
		  ,[NetVolume]
		  ,[TotalVolume]
		  ,[NoBuys]
		  ,[NoSells]
		  ,[Trades]
		  ,[BuyPrice]
		  ,[SellPrice]
		  ,[PercRank]
		  ,[CreateDate]
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[BrokerCode]
		  ,[Symbol]
		  ,[BuyValue]
		  ,[SellValue]
		  ,[NetValue]
		  ,[TotalValue]
		  ,[BuyVolume]
		  ,[SellVolume]
		  ,[NetVolume]
		  ,[TotalVolume]
		  ,[NoBuys]
		  ,[NoSells]
		  ,[Trades]
		  ,[BuyPrice]
		  ,[SellPrice]
		  ,[PercRank]
		  ,[CreateDate]
		from [StockData].[BrokerReport] as a
		where exists
		(
			select 1
			from #TempBrokerReportToArchive
			where ObservationDate = a.ObservationDate
			and ASXCode = a.ASXCode
		)

		delete a
		from [StockData].[BrokerReport] as a
		where exists
		(
			select 1
			from #TempBrokerReportToArchive
			where ObservationDate = a.ObservationDate
			and ASXCode = a.ASXCode
		)

		delete a
		from [StockData].[CourseOfSaleSecondary] as a
		where ObservationDate < dateadd(day, -60, getdate())

		delete a
		from Archive.PriceSummaryHistory as a
		where ObservationDate < dateadd(day, -365, getdate()) 

		if object_id(N'Tempdb.dbo.#TempCustomFilterDetail') is not null
			drop table #TempCustomFilterDetail

		select distinct
			a.ASXCode,
			b.CustomFilter,
			cast(a.CreateDate as date) as ObservationDate,
			getdate() as CreateDate
		into #TempCustomFilterDetail
		from StockData.CustomFilterDetail as a
		inner join StockData.CustomFilter as b
		on a.CustomFilterID = b.CustomFilterID
		where len(a.ASXCode) <= 10
		and CustomFilter not like 'Monitor %'
		and CustomFilter not like 'Sector %'

		delete a
		from StockData.CustomFilterHistory as a
		inner join 
		(
			select distinct ObservationDate
			from #TempCustomFilterDetail 
		) as b
		on a.ObservationDate = b.ObservationDate

		insert into StockData.CustomFilterHistory
		(
			ASXCode,
			CustomFilter,
			ObservationDate,
			CreateDate
		)
		select 
			ASXCode,
			CustomFilter,
			ObservationDate,
			CreateDate
		from #TempCustomFilterDetail 

		delete a
		from StockData.StockTickerDetail as a
		where CreateDate < dateadd(day, -20, getdate())

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		select *
		into #TempOptionBidAsk
		from StockData.OptionBidAsk as a with(nolock)
		where ObservationDateLocal < dateadd(day, -20, getdate())

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

		--insert into [StockData].[CourseOfSaleSecondary]
		--(
		--	   [SaleDateTime]
		--	  ,[Price]
		--	  ,[Quantity]
		--	  ,[ASXCode]
		--	  ,[ExChange]
		--	  ,[SpecialCondition]
		--	  ,[CreateDate]
		--	  ,[ActBuySellInd]
		--	  ,[DerivedInstitute]
		--	  ,[ObservationDate]
		--)
		--select
		--	   [SaleDateTime]
		--	  ,[Price]
		--	  ,[Quantity]
		--	  ,[ASXCode]
		--	  ,[ExChange]
		--	  ,[SpecialCondition]
		--	  ,[CreateDate]
		--	  ,[ActBuySellInd]
		--	  ,[DerivedInstitute]
		--	  ,[ObservationDate]
		--from [StockData].[CourseOfSaleSecondaryToday] as a with(nolock)
		--where not exists
		--(
		--	select 1
		--	from [StockData].[CourseOfSaleSecondary]
		--	where SaleDateTime = a.SaleDateTime
		--	and ASXCode = a.ASXCode
		--	and Price = a.Price
		--	and Quantity = a.Quantity
		--	and ExChange = a.ExChange
		--	and ObservationDate = a.ObservationDate
		--)

		--truncate table [StockData].[CourseOfSaleSecondaryToday]

		if object_id(N'Tempdb.dbo.#TempStockBidAsk') is not null
			drop table #TempStockBidAsk

		select *
		into #TempStockBidAsk
		from StockData.StockBidAsk as a
		where CreateDateTime < dateadd(hour, -25, getdate())

		insert into ArchiveDB.StockData.StockBidAsk
		(
		   [ASXCode]
		  ,[ObservationTime]
		  ,[PriceBid]
		  ,[SizeBid]
		  ,[PriceAsk]
		  ,[SizeAsk]
		  ,[ObservationDate]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		)
		select
		   [ASXCode]
		  ,[ObservationTime]
		  ,[PriceBid]
		  ,[SizeBid]
		  ,[PriceAsk]
		  ,[SizeAsk]
		  ,[ObservationDate]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		from #TempStockBidAsk

		delete a
		from StockData.StockBidAsk as a
		inner join #TempStockBidAsk as b
		on a.StockBidAskID = b.StockBidAskID

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
