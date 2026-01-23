-- Stored procedure: [Report].[usp_GetSectorPerformance]



CREATE PROCEDURE [Report].[usp_GetSectorPerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchToken as varchar(200)
AS
/******************************************************************************
File: usp_GetSectorPerformance.sql
Stored Procedure Name: usp_GetSectorPerformance
Overview
-----------------
usp_GetSectorPerformance

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
Date:		2017-03-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetSectorPerformance'
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
		select
		   SMA0.[Token]
		  ,cast(SMA0.[ObservationDate] as varchar(50)) as ObservationDate
		  ,VSMA5.VSMA5/1000 as [TradeValue]
		  ,SMA0.[ASXCode]
		  ,SMA0.SMA0
		  ,SMA3.SMA3
		  ,SMA5.SMA5
		  ,SMA10.SMA10
		  ,SMA20.SMA20
		  ,SMA30.SMA30
		from
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA0
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA0'
		) as SMA0
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA3
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA3'
		) as SMA3
		on SMA0.Token = SMA3.Token
		and SMA0.ObservationDate = SMA3.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA5
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA5'
		) as SMA5
		on SMA0.Token = SMA5.Token
		and SMA0.ObservationDate = SMA5.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA10
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA10'
		) as SMA10
		on SMA0.Token = SMA10.Token
		and SMA0.ObservationDate = SMA10.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA20
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA20'
		) as SMA20
		on SMA0.Token = SMA20.Token
		and SMA0.ObservationDate = SMA20.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as SMA30
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'SMA30'
		) as SMA30
		on SMA0.Token = SMA30.Token
		and SMA0.ObservationDate = SMA30.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as VSMA5
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'VSMA5'
		) as VSMA5
		on SMA0.Token = VSMA5.Token
		and SMA0.ObservationDate = VSMA5.ObservationDate
		left join
		(
			select distinct
			   [Token]
			  ,[ObservationDate]
			  ,TradeValue
			  ,ASXCode
			  ,MAAvgHoldValue as VSMA50
			from Report.SectorPerformance 
			where Token = @pvchToken
			and [MAAvgHoldKey] = 'VSMA50'
		) as VSMA50
		on SMA0.Token = VSMA50.Token
		and SMA0.ObservationDate = VSMA50.ObservationDate

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
