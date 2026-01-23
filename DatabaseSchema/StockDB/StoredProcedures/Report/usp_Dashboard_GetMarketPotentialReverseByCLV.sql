-- Stored procedure: [Report].[usp_Dashboard_GetMarketPotentialReverseByCLV]



create PROCEDURE [Report].[usp_Dashboard_GetMarketPotentialReverseByCLV]
@pbitDebug AS BIT = 0
AS
/******************************************************************************
File: usp_Dashboard_GetMarketCLVTrend.sql
Stored Procedure Name: usp_Dashboard_GetMarketCLVTrend
Overview
-----------------
usp_Dashboard_GetMarketCLVTrend

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
Date:		2023-09-05
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	declare @pintErrorNumber as int = 0

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Dashboard_GetMarketPotentialReverseByCLV_SPX'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		--Check Market CLV		
		select 
		'SPX' as IndexType,
		a.ObservationDate, 
		a.ReverseFromPrev as ReverseFromPrev, 
		a.PotentialReversed as PotentialReversed, 
		c.TomorrowChange, 
		c.Next2DaysChange, 
		c.Next5DaysChange,
		c.Last3DaysChange,
		c.Prev2DaysChange,
		c.TodayChange,
		a.CLV,
		case when a.ReverseFromPrev = 1 or a.ReverseFromPrev = 1 then case when c.Last2DaysChange < -0.5 then 1 when c.Last2DaysChange > 0.5 then 0 end end as SwingIndicator_Type1,
		case when a.PotentialReversed = 1 or a.PotentialReversed = 1 then case when c.Last2DaysChange < -0.5 then 1 when c.Last2DaysChange > 0.5 then 0 end end as SwingIndicator_Type2,
		c.[Close]
		from
		(
			select * from StockDB_US.Transform.v_MarketPotentialReverseByCLV_SPX
			--order by ObservationDate desc;
		) as a
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory with(nolock)
			where ASXCode = 'SPX'
		) as c
		on a.ObservationDate = c.ObservationDate
		union
		select 
			'NASDAQ' as IndexType,
			a.ObservationDate, 
			a.ReverseFromPrev as ReverseFromPrev, 
			a.PotentialReversed as PotentialReversed, 
			c.TomorrowChange, 
			c.Next2DaysChange, 
			c.Next5DaysChange,
			c.Last3DaysChange,
			c.Prev2DaysChange,
			c.TodayChange,
			a.CLV,
			case when a.ReverseFromPrev = 1 or a.ReverseFromPrev = 1 then case when c.Last2DaysChange < -0.5 then 1 when c.Last2DaysChange > 0.5 then 0 end end as SwingIndicator_Type1,
			case when a.PotentialReversed = 1 or a.PotentialReversed = 1 then case when c.Last2DaysChange < -0.5 then 1 when c.Last2DaysChange > 0.5 then 0 end end as SwingIndicator_Type2,
			c.[Close]
		from
		(
			select * from StockDB_US.Transform.v_MarketPotentialReverseByCLV_NASDAQ
			--order by ObservationDate desc;
		) as a
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory with(nolock)
			where ASXCode = 'NASDAQ'
		) as c
		on a.ObservationDate = c.ObservationDate

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
