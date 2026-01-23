-- Stored procedure: [DataMaintenance].[usp_RefreshBrokerPerformance]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshBrokerPerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshBrokerPerformance.sql
Stored Procedure Name: usp_RefreshBrokerPerformance
Overview
-----------------
usp_RefreshBrokerPerformance

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
Date:		2018-02-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBrokerPerformance'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		delete a
		from [Transform].[BrokerInsight] as a

		dbcc checkident('[Transform].[BrokerInsight]', reseed, 1);

		declare @vchMCRange as varchar(100), @intNumDays as int
		declare curBrokerPerfRefresh cursor for
		select MCRange, NumDays
		from
		(
			select '0-50M' as MCRange
			union
			select '50-300M' as MCRange
			union
			select '300-2000M' as MCRange
			union
			select '2000-10000M' as MCRange
		) as a
		cross join 
		(
			select 1 as NumDays
			union
			select 3 as NumDays
			union
			select 5 as NumDays
			union
			select 10 as NumDays
			union
			select 20 as NumDays
			union
			select 60 as NumDays
		) as b

		open curBrokerPerfRefresh

		fetch curBrokerPerfRefresh into @vchMCRange, @intNumDays
		
		while @@fetch_status = 0
		begin
			print @vchMCRange
			print @intNumDays

			exec [StockData].[usp_RefreshBrokerPerformance]
				@pvchMCRange = @vchMCRange,
				@pintXNumDaysPerformance = @intNumDays

			fetch curBrokerPerfRefresh into @vchMCRange, @intNumDays
		end

		close curBrokerPerfRefresh
		deallocate curBrokerPerfRefresh

		if object_id(N'[Transform].[BrokerInsightSummary]') is not null
			drop table [Transform].[BrokerInsightSummary]

		select 
			MCRange, 
			NumDays, 
			BrokerCode,
			LongShort,
			cast(year(ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(ObservationDate) as varchar(10)), 2) as YearMonth,
			min(AggPercOfWin) as AggPercOfWin,
			min(AggPercReturn) as AggPercReturn
		into [Transform].[BrokerInsightSummary]
		from [Transform].[BrokerInsight] with(nolock)
		where BrokerCode is not null
		group by 
			MCRange, 
			NumDays, 
			BrokerCode,
			LongShort,
			cast(year(ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(ObservationDate) as varchar(10)), 2) 


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
