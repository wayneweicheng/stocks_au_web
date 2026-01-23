-- Stored procedure: [StockData].[usp_GetMostActiveOptionContract_SignificantTradeBidAskTime]



CREATE PROCEDURE [StockData].[usp_GetMostActiveOptionContract_SignificantTradeBidAskTime]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchOptionSymbol as varchar(100),
@pvchObservationDate as varchar(50)
AS
/******************************************************************************
File: usp_GetMostActiveOptionContract_SignificantTradeBidAskTime.sql
Stored Procedure Name: usp_GetMostActiveOptionContract_SignificantTradeBidAskTime
Overview
-----------------
usp_GetMostActiveOptionContract_SignificantTradeBidAskTime

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_GetMostActiveOptionContract_SignificantTradeBidAskTime]
@pvchOptionSymbol = 'SPY230414C00412000',
@pvchObservationDate = '2023-04-13'

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMostActiveOptionContract_SignificantTradeBidAskTime'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here		
		--declare @pvchOptionSymbol as varchar(100) = 'SPX230421P03675000'
		--declare @pvchObservationDate as varchar(50) = '2023-04-14'

		if object_id(N'Tempdb.dbo.#TempQueryBidAsk') is not null
			drop table #TempQueryBidAsk

		if object_id(N'Tempdb.dbo.#TempMaxTime') is not null
			drop table #TempMaxTime

		declare @intSizePrice as int = 100

		select OptionTradeID, ASXCode, OptionSymbol, dateadd(second, -30, SaleTime) as StartDateTime, dateadd(second, 30, SaleTime) as EndDateTime, SaleTime, OptionTradeID as GroupID
		into #TempQueryBidAsk
		from StockData.OptionTrade as a with(nolock) 
		where OptionSymbol = @pvchOptionSymbol --'SPY230315C00365000'
		and ObservationDateLocal = @pvchObservationDate --'2023-03-15'
		and 
		(
			(ASXCode in ('SPY.US') and (Size*Price >= 100 or Size*Price < 20))
			or
			(ASXCode in ('QQQ.US') and Size*Price >= @intSizePrice)
			or
			(ASXCode in ('SPXW.US') and Size*Price >= @intSizePrice)
			or
			(ASXCode in ('SPX.US') and Size*Price >= @intSizePrice)
		)
		--and isnull(QueryBidNum, 0) <= 3
		and isnull(BuySellIndicator, '') not in ('B', 'S')
		--and OptionTradeID = 288127064
		and 
		(
			not exists
			(
				select 1
				from StockData.OptionBidAskRequest with(nolock)
				where 1 = 1
				and OptionSymbol = @pvchOptionSymbol --'SPY230315C00365000'
				and ObservationDate = @pvchObservationDate --'2023-03-15'
				and a.SaleTime >= StartDateTime
				and a.SaleTime <= EndDateTime
			)
		)
		order by a.SaleTime

		declare @intNumRecords as int
		select @intNumRecords = count(*)
		from #TempQueryBidAsk

		if @intNumRecords > 2000
		begin
			update a
			set a.GroupID = b.GroupID
			from #TempQueryBidAsk as a
			inner join (
				select min(GroupID) as GroupID
				from #TempQueryBidAsk
			) as b
			on 1 = 1
			
		end
		else
		begin
			declare @intNum as int = 1
			declare @intLoopCount as int = 0

			while @intNum > 0 and @intLoopCount < 200
			begin
				select @intNum = 0

				update a
				set a.GroupID = b.GroupID
				from #TempQueryBidAsk as a
				inner join #TempQueryBidAsk as b
				on 1 = 1
				and 
				(
					(b.EndDateTime <= a.EndDateTime and b.EndDateTime >= a.StartDateTime) 
					--or
					--(a.EndDateTime <= b.EndDateTime and a.EndDateTime >= b.StartDateTime)
				)
				and a.GroupID > b.GroupID

				select @intNum = @intNum + @@ROWCOUNT

				update a
				set a.GroupID = b.GroupID
				from #TempQueryBidAsk as a
				inner join #TempQueryBidAsk as b
				on 1 = 1
				and 
				(
					(a.EndDateTime <= b.EndDateTime and a.EndDateTime >= b.StartDateTime)
				)
				and a.GroupID > b.GroupID

				select @intNum = @intNum + @@ROWCOUNT

				print @intNum 
				print @intLoopCount

				select @intLoopCount = @intLoopCount + 1
			end
		end

		update a
		set a.StartDateTime = b.StartDateTime,
			a.EndDateTime = b.EndDateTime
		from #TempQueryBidAsk as a
		inner join
		(
			select GroupID, min(StartDateTime) as StartDateTime, max(EndDateTime) as EndDateTime
			from #TempQueryBidAsk as a
			group by GroupID
		) as b
		on a.GroupID = b.GroupID

		--select
		--	ASXCode, OptionSymbol, max(SaleTime) as SaleTime
		--into #TempMaxTime
		--from StockData.OptionTrade with(nolock)
		--where OptionSymbol = @pvchOptionSymbol --'SPY230315C00365000'
		--and ObservationDateLocal = @pvchObservationDate --'2023-03-15'
		--and 
		--(
		--	(ASXCode in ('SPY.US') and (Size*Price >= 100 or Size*Price < 20))
		--	or
		--	(ASXCode in ('QQQ.US') and Size*Price >= @intSizePrice)
		--	or
		--	(ASXCode in ('SPXW.US') and Size*Price >= @intSizePrice)
		--	or
		--	(ASXCode in ('SPX.US') and Size*Price >= @intSizePrice)
		--)
		--and isnull(QueryBidNum, 0) <= 3
		--and isnull(BuySellIndicator, '') in ('B', 'S')
		--group by ASXCode, OptionSymbol

		update a
		set a.QueryBidAskAt = getdate(),
			a.QueryBidNum = isnull(a.QueryBidNum, 0) + 1
		from StockData.OptionTrade as a
		inner join #TempQueryBidAsk as b
		on a.OptionTradeID = b.OptionTradeID
		where a.OptionSymbol = @pvchOptionSymbol --'SPY230315C00365000'
		and ObservationDateLocal = @pvchObservationDate --'2023-03-15'

		select
			ASXCode,
			OptionSymbol,
			CONVERT(datetime, SWITCHOFFSET(StartDateTime, DATEPART(TZOFFSET, StartDateTime AT TIME ZONE 'AUS Eastern Standard Time'))) as StartDateTime,
			CONVERT(datetime, SWITCHOFFSET(EndDateTime, DATEPART(TZOFFSET, EndDateTime AT TIME ZONE 'AUS Eastern Standard Time'))) as EndDateTime,
			StartDateTime as StartDateTimeRaw,
			EndDateTime as EndDateTimeRaw
		into #TempOptionSymbol
		from
		(
			select a.ASXCode, a.OptionSymbol, StartDateTime, EndDateTime
			from #TempQueryBidAsk as a
			--inner join #TempMaxTime as b
			--on a.OptionSymbol = b.OptionSymbol
			--and a.SaleTime > b.SaleTime
			group by a.ASXCode, a.OptionSymbol, StartDateTime, EndDateTime
		) as a

		select 
			ASXCode,
			OptionSymbol,
			StartDateTime,
			EndDateTime,
			StartDateTimeRaw,
			EndDateTimeRaw
		from #TempOptionSymbol
		order by StartDateTime

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
