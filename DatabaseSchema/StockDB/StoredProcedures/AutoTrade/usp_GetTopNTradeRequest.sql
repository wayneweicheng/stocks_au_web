-- Stored procedure: [AutoTrade].[usp_GetTopNTradeRequest]

CREATE PROCEDURE [AutoTrade].[usp_GetTopNTradeRequest]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintTopN as int = 500,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_GetTradeRequest.sql
Stored Procedure Name: usp_GetTradeRequest
Overview
-----------------
usp_GetTradeRequest

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
Date:		2018-01-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTradeRequest'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'AutoTrade'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--declare @pintNumPrevDay as int = 0
		--declare @pintTopN as int = 100

		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempStockNature') is not null
			drop table #TempStockNature

		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		into #TempStockNature
		from StockData.StockNature as a
		group by a.ASXCode

		if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
			drop table #TempDirectorCurrent

		select a.ASXCode, a.DirName
		into #TempDirectorCurrent
		from StockData.DirectorCurrentPvt as a
	
		--declare @pintNumPrevDay as int = 0

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			[Value] decimal(20, 4) 
		)

		insert into #TempPriceSummary
		(
			ASXCode,
			[Open],
			[Close],
			[PrevClose],
			[Value]
		)
		select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, [Value]
		from StockData.PriceSummary as a
		--inner join StockData.PriceHistoryCurrent as b
		--on a.ASXCode = b.ASXCode
		where ObservationDate = cast(dateadd(day, -1*@pintNumPrevDay, getdate()) as date)
		and LatestForTheDay = 1

		if not exists
		(
			select 1
			from #TempPriceSummary
		)
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				[Value]
			)
			select
				ASXCode,
				[Open],
				[Close],
				null as [PrevClose],
				[Value]
			from StockData.PriceHistoryCurrent
		end

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		if object_id(N'Tempdb.dbo.#TempPostRaw') is not null
			drop table #TempPostRaw

		select
			PostRawID,
			ASXCode,
			Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		into #TempPostRaw
		from HC.TempPostLatest

		SELECT top (@pintTopN)
			   [TradeRequestID]
			  ,a.[ASXCode]
			  ,[BuySellFlag]
			  ,case when a.[Price] = 0 then j.[Close] else a.Price end as TipPrice
			  ,h.[Close] as CurrentPrice
			  ,case when case when a.[Price] = 0 then j.[Close] else a.Price end > 0 then cast((h.[Close] - case when a.[Price] = 0 then j.[Close] else a.Price end)*100.0/case when a.[Price] = 0 then j.[Close] else a.Price end as decimal(10, 2)) else 0 end as ChangePerc
			  --,[StopLossPrice]
			  ,[StopProfitPrice]
			  --,[MinVolume]
			  --,[MaxVolume]
			  --,[RequestValidTimeFrameInMin]
			  --,[RequestValidUntil]
			  ,a.[CreateDate]
			  --,[LastTryDate]
			  --,[OrderPlaceDate]
			  --,[OrderPlaceVolume]
			  --,[OrderReceiptID]
			  --,[OrderFillDate]
			  --,[OrderFillVolume]
			  --,[RequestStatus]
			  --,[RequestStatusMessage]
			  --,[PreReqTradeRequestID]
			  --,[AccountNumber]
			  ,[TradeStrategyID]
			  ,[ErrorCount]
			  ,[TradeStrategyMessage]
			  ,[TradeRank]
			  ,cast(c.MC as decimal(8, 2)) as MC
			  ,cast(c.CashPosition as decimal(8, 2)) CashPosition
			  ,format(AvgValue90d, 'N0') as AvgValue90d
			  ,cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K]
			  ,cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC
			  ,cast(d.Nature as varchar(100)) as Nature
			  ,i.Poster
			  --,g.DirName
		  FROM [AutoTrade].[TradeRequest] as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join StockData.PriceHistory as j
			on a.ASXCode = j.ASXCode
			and cast(a.CreateDate as date) = j.ObservationDate
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, avg([Value]*[Close]) as AvgValue90d from StockData.PriceHistory
				where 1 = 1
				and datediff(day, ObservationDate, getdate()) <= 90
				group by ASXCode			
			) as x
			on a.ASXCode = x.ASXCode
		  --where a.ASXCode = 'AGH.AX'
		  order by a.CreateDate desc

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