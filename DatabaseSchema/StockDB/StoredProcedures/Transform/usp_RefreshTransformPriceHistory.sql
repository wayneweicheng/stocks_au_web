-- Stored procedure: [Transform].[usp_RefreshTransformPriceHistory]





CREATE PROCEDURE [Transform].[usp_RefreshTransformPriceHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformPriceHistory.sql
Stored Procedure Name: usp_RefreshTransformPriceHistory
Overview
-----------------
usp_RefreshTransformPriceHistory

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
Date:		2020-11-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformPriceHistory'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Transform'
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
		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		SELECT [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,cast(null as decimal(20, 4)) as VWAP
			  ,lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose
			  ,cast(null as decimal(20, 4)) as PriceChangeVsPrevClose
			  ,case when [Open] > 0 then cast(([Close] - [Open])*100.0/[Open] as decimal(10, 2)) else null end as PriceChangeVsOpen
			  ,([High] - [Low]) as Spread
			  ,[CreateDate]
			  ,[ModifyDate]
		into #TempPriceHistory
		FROM [StockData].[PriceHistory]
		where ObservationDate >  dateadd(day, -30*2, getdate())

		update a
		set PriceChangeVsPrevClose = case when [PrevClose] > 0 then cast(([Close] - [PrevClose])*100.0/[PrevClose] as decimal(10, 2)) else null end
		from #TempPriceHistory as a

		update a
		set a.VWAP = b.VWAP
		from #TempPriceHistory as a
		inner join StockData.v_PriceSummaryHistory as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		--and a.VWAP is null
		and b.VWAP > 0
		and b.DateTo is null
		and b.LatestForTheDay = 1
		and cast(b.LastVerifiedDate as time) > cast('15:30:00' as time)
		
		insert into Transform.PriceHistory
		(
			   [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[PrevClose]
			  ,[PriceChangeVsPrevClose]
			  ,[PriceChangeVsOpen]
			  ,[Spread]
			  ,[CreateDate]
			  ,[ModifyDate]
			  ,[TransformDate]
		)
		select
			   [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[PrevClose]
			  ,[PriceChangeVsPrevClose]
			  ,[PriceChangeVsOpen]
			  ,[Spread]
			  ,[CreateDate]
			  ,[ModifyDate]
			  ,getdate() as [TransformDate]
		from #TempPriceHistory as a
		where not exists
		(
			select 1
			from Transform.PriceHistory
			where ObservationDate = a.ObservationDate
			and ASXCode = a.ASXCode
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