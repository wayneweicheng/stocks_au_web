-- Stored procedure: [DataMaintenance].[usp_RefreshPriceSummaryTodayExtraInfo]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshPriceSummaryTodayExtraInfo]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshPriceSummaryTodayExtraInfo.sql
Stored Procedure Name: usp_RefreshPriceSummaryTodayExtraInfo
Overview
-----------------
usp_RefreshPriceSummaryTodayExtraInfo

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
Date:		2020-08-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPriceSummaryTodayExtraInfo'
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
		if object_id(N'Tempdb.dbo.#TempPriceSummaryToday') is not null
			drop table #TempPriceSummaryToday

		select *
		into #TempPriceSummaryToday
		from StockData.PriceSummaryToday

		update a
		set Prev1PriceSummaryID = null,
			SeqNumber = null,
			[Value] = null,
			[VWAP] = null
		from #TempPriceSummaryToday as a

		update a
		set a.SeqNumber = isnull(b.RowNumber, 0)
		from #TempPriceSummaryToday as a
		left join
		(
			select 
			PriceSummaryID, 
			ASXCode, 
			ObservationDate,
			row_number() over (partition by ASXCode, ObservationDate order by DateFrom) as RowNumber
			from #TempPriceSummaryToday
		) as b
		on a.PriceSummaryID = b.PriceSummaryID

		update a
		set a.Prev1PriceSummaryID = b.PriceSummaryID
		from #TempPriceSummaryToday as a
		inner join #TempPriceSummaryToday as b
		on a.SeqNumber - 1 = b.SeqNumber
		and a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set a.[Value] = a.Volume*(Bid + Offer)/2.0,
			a.VWAP = (Bid + Offer)/2.0
		from #TempPriceSummaryToday as a
		where SeqNumber = 1
		and [Value] is null

		update a
		set VWAP = (a.Bid + a.Offer)/2.0,
			Volume = 0,
			[Value] = 0
		from #TempPriceSummaryToday as a
		where SeqNumber = 1
		and Volume is null

		declare @intNumUpdate as int = 1

		while @intNumUpdate > 0
		begin
			select @intNumUpdate = 0

			update a
			set a.[Volume] = b.[Volume]
			from #TempPriceSummaryToday as a
			inner join #TempPriceSummaryToday as b
			on a.Prev1PriceSummaryID = b.PriceSummaryID
			where a.[Volume] is null
			and b.[Volume] is not null

			select @intNumUpdate = @intNumUpdate + @@ROWCOUNT

			update a
			set a.[Value] = b.[Value] + (a.Volume - b.Volume)*(a.Bid + a.Offer)/2.0
			from #TempPriceSummaryToday as a
			inner join #TempPriceSummaryToday as b
			on a.Prev1PriceSummaryID = b.PriceSummaryID
			where a.[Value] is null
			and b.[Value] is not null

			select @intNumUpdate = @intNumUpdate + @@ROWCOUNT

		end

		update a
		set VWAP = Value*1.0/Volume
		from #TempPriceSummaryToday as a
		where Volume > 0

		update x
		set x.Prev1Bid = y.Bid,
			x.Prev1Offer = y.Offer,
			x.Prev1Volume = y.Volume,
			x.Prev1Value = y.[Value],
			x.VolumeDelta = x.Volume - y.Volume,
			x.ValueDelta = x.[Value] - y.[Value],
			x.TimeIntervalInSec = datediff(second, y.LastVerifiedDate, x.DateFrom),
			x.Prev1Close = y.[close]
		from #TempPriceSummaryToday as x
		inner join #TempPriceSummaryToday as y
		on x.Prev1PriceSummaryID = y.PriceSummaryID 
		
		update x
		set x.BuySellInd = case when x.VolumeDelta > 0 and x.[close] = x.Prev1Offer and x.[close] > x.Prev1Bid then 'B'
								when x.VolumeDelta > 0 and x.[close] = x.Prev1Bid and x.[close] < x.Prev1Offer then 'S'
								when x.VolumeDelta > 0 and x.[close] > x.[Prev1Close] then 'B'
								when x.VolumeDelta > 0 and x.[close] < x.[Prev1Close] then 'S'
								when x.VolumeDelta > 0 and x.[bid] > x.[Prev1Bid] and x.[Offer] >= x.[Prev1Offer] then 'B'
								when x.VolumeDelta > 0 and x.[offer] < x.[Prev1Offer] and x.[Bid] <= x.[Prev1Bid] then 'S'
								else null
							end
		from #TempPriceSummaryToday as x
		
		update x
		set x.BuySellInd = case when x.VWAP > y.VWAP then 'B'
								when x.VWAP < y.VWAP then 'S'
								else null
							end
		from #TempPriceSummaryToday as x
		inner join #TempPriceSummaryToday as y
		on x.Prev1PriceSummaryID = y.PriceSummaryID 
		where x.BuySellInd is null

		update a
		set a.SeqNumber = b.SeqNumber,
			a.Prev1PriceSummaryID = b.Prev1PriceSummaryID,
			a.Volume = isnull(a.Volume, b.Volume),
			a.[Value] = b.[Value],
			a.VWAP = b.VWAP,
			a.Prev1Bid = b.Prev1Bid,
			a.Prev1Offer = b.Prev1Offer,
			a.Prev1Volume = b.Prev1Volume,
			a.Prev1Value = b.Prev1Value,
			a.VolumeDelta = b.VolumeDelta,
			a.ValueDelta = b.ValueDelta,
			a.TimeIntervalInSec = b.TimeIntervalInSec,
			a.Prev1Close = b.Prev1Close,
			a.BuySellInd = b.BuySellInd
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummaryToday as b
		on a.PriceSummaryID = b.PriceSummaryID

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