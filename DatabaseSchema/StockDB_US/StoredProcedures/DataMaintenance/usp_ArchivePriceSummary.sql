-- Stored procedure: [DataMaintenance].[usp_ArchivePriceSummary]





CREATE PROCEDURE [DataMaintenance].[usp_ArchivePriceSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_ArchivePriceSummary.sql
Stored Procedure Name: usp_ArchivePriceSummary
Overview
-----------------
usp_ArchivePriceSummary

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
Date:		2019-03-19
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_ArchivePriceSummary'
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
		if object_id(N'Tempdb.dbo.#TempPriceSummaryDelta') is not null
			drop table #TempPriceSummaryDelta

		select 
		   PriceSummaryID
		  ,[ASXCode]
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
		  ,[LastVerifiedDate]
		  ,[bids]
		  ,[bidsTotalVolume]
		  ,[offers]
		  ,[offersTotalVolume]
		  ,[IndicativePrice]
		  ,[SurplusVolume]
		  ,[MatchVolume]
		  ,[PrevClose]
		  ,[SysLastSaleDate]
		  ,[SysCreateDate]
		  ,[Prev1PriceSummaryID]
		  ,[Prev1Bid]
		  ,[Prev1Offer]
		  ,[Prev1Volume]
		  ,[Prev1Value]
		  ,[VolumeDelta]
		  ,[ValueDelta]
		  ,[TimeIntervalInSec]
		  ,[BuySellInd]
		  ,[Prev1Close]
		  ,[LatestForTheDay]
		  ,[ObservationDate]
		  ,SeqNumber
		into #TempPriceSummaryDelta 
		from [StockData].[PriceSummaryToday] as a with(nolock)

		insert into [StockData].[PriceSummary]
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
		  ,[LastVerifiedDate]
		  ,[bids]
		  ,[bidsTotalVolume]
		  ,[offers]
		  ,[offersTotalVolume]
		  ,[IndicativePrice]
		  ,[SurplusVolume]
		  ,[MatchVolume]
		  ,[PrevClose]
		  ,[SysLastSaleDate]
		  ,[SysCreateDate]
		  ,[Prev1PriceSummaryID]
		  ,[Prev1Bid]
		  ,[Prev1Offer]
		  ,[Prev1Volume]
		  ,[Prev1Value]
		  ,[VolumeDelta]
		  ,[ValueDelta]
		  ,[TimeIntervalInSec]
		  ,[BuySellInd]
		  ,[Prev1Close]
		  ,[LatestForTheDay]
		  ,[ObservationDate]
		  ,SeqNumber
		)
		select
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
		  ,[LastVerifiedDate]
		  ,[bids]
		  ,[bidsTotalVolume]
		  ,[offers]
		  ,[offersTotalVolume]
		  ,[IndicativePrice]
		  ,[SurplusVolume]
		  ,[MatchVolume]
		  ,[PrevClose]
		  ,[SysLastSaleDate]
		  ,[SysCreateDate]
		  ,[Prev1PriceSummaryID]
		  ,[Prev1Bid]
		  ,[Prev1Offer]
		  ,[Prev1Volume]
		  ,[Prev1Value]
		  ,[VolumeDelta]
		  ,[ValueDelta]
		  ,[TimeIntervalInSec]
		  ,[BuySellInd]
		  ,[Prev1Close]
		  ,[LatestForTheDay]
		  ,[ObservationDate]
		  ,SeqNumber
		from #TempPriceSummaryDelta as a
		where not exists
		(
			select 1
			from StockData.PriceSummary
			where ASXCode = a.ASXCode
			and DateFrom = a.DateFrom
		)

		delete a
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummaryDelta as b
		on a.PriceSummaryID = b.PriceSummaryID

		update a
		set a.LatestForTheDay = 0
		from [StockData].[PriceSummary] as a
		where DateTo is not null
		and LatestForTheDay = 1
		and ObservationDate = cast(getdate() as date)

		update a
		set LatestForTheDay = 0
		from StockData.PriceSummary as a
		where a.LatestForTheDay = 1
		and DateTo is not null

		update a
		set a.LatestForTheDay = 0
		from StockData.PriceSummary as a
		inner join 
		(
			select
				PriceSummaryID,
				row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from StockData.PriceSummary
			where DateTo is null
		) as b
		on a.PriceSummaryID = b.PriceSummaryID
		and a.LatestForTheDay = 1
		and b.RowNumber > 1
		and a.DateTo is null

		exec [StockData].[usp_RefreshWatchList]

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
