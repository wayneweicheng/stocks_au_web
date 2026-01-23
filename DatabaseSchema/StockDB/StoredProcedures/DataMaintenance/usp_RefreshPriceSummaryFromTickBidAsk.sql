-- Stored procedure: [DataMaintenance].[usp_RefreshPriceSummaryFromTickBidAsk]


CREATE PROCEDURE [DataMaintenance].[usp_RefreshPriceSummaryFromTickBidAsk]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshPriceSummaryFromTickBidAsk.sql
Stored Procedure Name: usp_RefreshPriceSummaryFromTickBidAsk
Overview
-----------------
usp_RefreshPriceSummaryFromTickBidAsk

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
Date:		2023-11-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPriceSummaryFromTickBidAsk'
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
		--begin transaction
		if object_id(N'Tempdb.dbo.#TempPriceSummaryRaw') is not null
			drop table #TempPriceSummaryRaw
		select 
			identity(int, 1, 1) as UniqueKey, 
			cast(DateFrom as smalldatetime) as DateTimeWindow,
			cast(0 as bit) as IsLast,
			cast(0 as bit) as IsFirst,
			cast(0 as bit) as IsLastPrice,
			cast(0 as bit) as IsFirstPrice,
			*
		into #TempPriceSummaryRaw
		from StockData.v_StockTickSaleVsBidAsk_All with(nolock)
		where ObservationDate = cast(getdate() as date)
		and Price > 0
		--and ASXCode in ('LTR.AX', 'BNR.AX')

		update a
		set IsLast = 1
		from #TempPriceSummaryRaw as a
		inner join
		(
			select UniqueKey, row_number() over (partition by ASXCode, DateTimeWindow order by DateFrom desc, SaleDateTime desc) as RowNumber
			from #TempPriceSummaryRaw
		) as b
		on a.UniqueKey = b.UniqueKey
		and b.RowNumber = 1

		update a
		set IsFirst = 1
		from #TempPriceSummaryRaw as a
		inner join
		(
			select UniqueKey, row_number() over (partition by ASXCode, DateTimeWindow order by DateFrom asc, SaleDateTime asc) as RowNumber
			from #TempPriceSummaryRaw
		) as b
		on a.UniqueKey = b.UniqueKey
		and b.RowNumber = 1

		update a
		set IsLastPrice = 1
		from #TempPriceSummaryRaw as a
		inner join
		(
			select UniqueKey, row_number() over (partition by ASXCode, DateTimeWindow order by DateFrom desc, SaleDateTime desc) as RowNumber
			from #TempPriceSummaryRaw
			where Price > 0
		) as b
		on a.UniqueKey = b.UniqueKey
		and b.RowNumber = 1

		update a
		set IsFirstPrice = 1
		from #TempPriceSummaryRaw as a
		inner join
		(
			select UniqueKey, row_number() over (partition by ASXCode, DateTimeWindow order by DateFrom asc, SaleDateTime asc) as RowNumber
			from #TempPriceSummaryRaw
			where Price > 0
		) as b
		on a.UniqueKey = b.UniqueKey
		and b.RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempPriceSummaryBase') is not null
			drop table #TempPriceSummaryBase

		select 
			a.UniqueKey,
			a.ASXCode,
			a.PriceBid as Bid,
			a.PriceAsk as Offer,
			cast(null as decimal(20, 4)) as [Open],
			cast(null as decimal(20, 4)) as [High],
			cast(null as decimal(20, 4)) as [Low],
			cast(null as decimal(20, 4)) as [Close],
			cast(null as bigint) as [Volume],
			cast(null as decimal(20, 4)) as [Value],
			cast(null as int) as [Trades],
			cast(null as decimal(20, 4)) as [VWAP],
			DateFrom,
			DateTo,
			DateFrom as LastVerifiedDate,
			sum(Quantity) OVER (Partition by ASXCode ORDER BY DateTimeWindow, DateFrom, SaleDateTime ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as CulVolume,
			sum([SaleValue]) OVER (Partition by ASXCode ORDER BY DateTimeWindow, DateFrom, SaleDateTime ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as CulValue,
			cast(null as int) as CulTrades,
			DateTimeWindow,
			ObservationDate,
			row_number() over (partition by ASXCode, ObservationDate order by DateTimeWindow, DateFrom) as DateSeq
		into #TempPriceSummaryBase
		from #TempPriceSummaryRaw as a
		where IsLast = 1

		update a
		set a.Volume = b.Quantity,
			a.[Value] = b.SaleValue,
			a.Trades = b.Trades,
			a.[High] = b.[High],
			a.[Low] = b.[Low]
		from #TempPriceSummaryBase as a
		inner join 
		(
			select ASXCode, DateTimeWindow, sum(Quantity) as Quantity, sum(SaleValue) as SaleValue, count(Price) as Trades, max(Price) as [High], min(Price) as [Low]
			from #TempPriceSummaryRaw
			group by ASXCode, DateTimeWindow
		) as b
		on a.ASXCode = b.ASXCode
		and a.DateTimeWindow = b.DateTimeWindow

		update a
		set a.[Open] = b.Price
		from #TempPriceSummaryBase as a
		inner join #TempPriceSummaryRaw as b
		on a.ASXCode = b.ASXCode
		and a.DateTimeWindow = b.DateTimeWindow
		and b.IsFirstPrice = 1

		update a
		set a.[Close] = b.Price
		from #TempPriceSummaryBase as a
		inner join #TempPriceSummaryRaw as b
		on a.ASXCode = b.ASXCode
		and a.DateTimeWindow = b.DateTimeWindow
		and b.IsLastPrice = 1

		update a
		set a.[VWAP] = a.CulValue*1.0/a.CulVolume
		from #TempPriceSummaryBase as a
		where CulVolume > 0

		--declare @intNumUpdate as int = 1

		--while @intNumUpdate > 0
		--begin
		--	update a
		--	set a.[Open] = b.[Open],
		--		a.[Close] = b.[Close],
		--		a.[High] = b.[High],
		--		a.[Low] = b.[Low],
		--		a.[Volume] = b.[Volume],
		--		a.[Value] = b.[Value]
		--	from #TempPriceSummaryBase as a
		--	inner join #TempPriceSummaryBase as b
		--	on a.ASXCode = b.ASXCode
		--	and a.ObservationDate = b.ObservationDate
		--	and a.DateSeq = b.DateSeq + 1
		--	where a.[Open] is null
		--	and b.[Open] is not null

		--	select @intNumUpdate = @@rowcount

		--	print @intNumUpdate 
		--end

		insert into StockData.PriceSummaryToday
		(
			 [ASXCode]
			,[Bid]
			,[Offer]
			,[Open]
			,[High]
			,[Low]
			,[Close]
			,[Volume]
			,[Value]
			,[Trades]
			,[VWAP]
			,[DateFrom]
			,[DateTo]
			,LastVerifiedDate
			,bids
			,bidsTotalVolume
			,offers
			,offersTotalVolume
			,IndicativePrice
			,SurplusVolume
			,MatchVolume
			,PrevClose
			,SysCreateDate
			,ObservationDate
			,LatestForTheDay
			,SeqNumber
			,WatchListName
		)
		select
			   a.[ASXCode]
			  ,a.[Bid]
			  ,a.[Offer]
			  ,a.[Open]
			  ,a.[High]
			  ,a.[Low]
			  ,a.[Close]
			  ,a.CulVolume as [Volume]
			  ,a.CulValue as [Value]
			  ,a.CulTrades as [Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,0 as [bids]
			  ,0 as [bidsTotalVolume]
			  ,0 as [offers]
			  ,0 as [offersTotalVolume]
			  ,0 as [IndicativePrice]
			  ,0 as [SurplusVolume]
			  ,0 as MatchVolume
			  ,null as [PrevClose]
			  ,DateFrom as [SysCreateDate]
			  ,a.[ObservationDate]
			  ,0 as [LatestForTheDay]
			  ,a.DateSeq as [SeqNumber]
			  ,'WL01' as WatchListName
		from #TempPriceSummaryBase as a
		where not exists
		(
			select 1
			from StockData.PriceSummaryToday as c
			where a.ASXCode = c.ASXCode
			and a.ObservationDate = c.ObservationDate
			and isnull(a.Bid, -1) = isnull(c.Bid, -1)
			and isnull(a.Offer, -1) = isnull(c.Offer, -1)
			and isnull(a.[Open], -1) = isnull(c.[Open], -1)
			and isnull(a.[High], -1) = isnull(c.[High], -1)
			and isnull(a.Low, -1) = isnull(c.Low, -1)
			and isnull(a.[Close], -1) = isnull(c.[Close], -1)
			and isnull(a.Volume, -1) = isnull(c.Volume, -1)
			and isnull(a.Value, -1) = isnull(c.Value, -1)
			and isnull(a.Trades, -1) = isnull(c.Trades, -1)
			and c.DateTo is null
		)

		update x
		set x.SysLastSaleDate = y.SysLastSaleDate
		from StockData.PriceSummaryToday as x
		inner join
		(
			select
				a.ASXCode,
				a.Volume,
				a.ObservationDate,
				min(a.SysCreateDate) as SysLastSaleDate
			from StockData.PriceSummaryToday as a
			where 1 = 1 
			--and cast(a.DateFrom as date) = cast(getdate() as date)
			and exists
			(
				select 1
				from #TempPriceSummaryBase
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)
			group by
				a.ASXCode,
				a.Volume,
				a.ObservationDate
		) as y
		on x.ASXCode = y.ASXCode
		and x.Volume = y.Volume

		update x
		set x.SeqNumber = y.SeqNumber
		from StockData.PriceSummaryToday as x
		inner join
		(
			select 
				a.PriceSummaryID,
				a.ASXCode,
				a.DateFrom,
				a.ObservationDate,
				row_number() over (partition by ASXCode, ObservationDate order by DateFrom asc) as SeqNumber
			from StockData.PriceSummaryToday as a
			where exists
			(
				select 1
				from #TempPriceSummaryBase
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		and x.PriceSummaryID = y.PriceSummaryID

		update x
		set x.Prev1Bid = y.Bid,
			x.Prev1Offer = y.Offer,
			x.Prev1Volume = y.Volume,
			x.Prev1Value = y.Value,
			x.VolumeDelta = x.Volume - y.Volume,
			x.ValueDelta = x.[Value] - y.[Value] ,
			x.TimeIntervalInSec = datediff(second, y.DateFrom, x.DateFrom),
			x.Prev1Close = y.[Close]
		from StockData.PriceSummaryToday as x
		inner join StockData.PriceSummaryToday as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		and x.SeqNumber = y.SeqNumber + 1
		--and x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummaryBase
			where ASXCode = x.ASXCode
			and ObservationDate = x.ObservationDate
		)
			
		update x
		set x.BuySellInd = case when x.VolumeDelta > 0 and x.[close] = x.Prev1Offer and x.[close] > x.Prev1Bid then 'B'
								when x.VolumeDelta > 0 and x.[close] = x.Prev1Bid and x.[close] < x.Prev1Offer then 'S'
								when x.VolumeDelta > 0 and x.[close] > x.[Prev1Close] then 'B'
								when x.VolumeDelta > 0 and x.[close] < x.[Prev1Close] then 'S'
								else null
							end
		from StockData.PriceSummaryToday as x
		where 1 = 1
		--and x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummaryBase
			where ASXCode = x.ASXCode
			and ObservationDate = x.ObservationDate
		)		

		
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
