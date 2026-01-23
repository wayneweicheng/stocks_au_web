-- Stored procedure: [DataMaintenance].[usp_RefreshTransformPriceHistoryNetVolume]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformPriceHistoryNetVolume]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformPriceHistoryNetVolume.sql
Stored Procedure Name: usp_RefreshTransformPriceHistoryNetVolume
Overview
-----------------
usp_RefreshTransformPriceHistoryNetVolume

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformPriceHistoryNetVolume'
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
		delete a
		from Transform.PriceHistoryNetVolume as a
		where 
		(
			ObservationDate > Common.DateAddBusinessDay(-3, getdate()) 
			or
			(
				ObservationDate > Common.DateAddBusinessDay(-60, getdate()) 
				and
				TotalVolume is null
			)
			or
			(
				ObservationDate > Common.DateAddBusinessDay(-60, getdate()) 
				and
				NetVolume is null
			)
			or
			(
				ObservationDate > Common.DateAddBusinessDay(-60, getdate()) 
				and
				30*NetVolume < TotalVolume
			)
			or exists
			(
				select 1
				from StockData.PriceHistory with(nolock)
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
				and Volume > a.TotalVolume
			)
		)

		insert into [Transform].[PriceHistoryNetVolume]
		(
			[ASXCode],
			[ObservationDate],
			[NetVolume],
			[NetValue],
			[TotalVolume],
			[TotalValue],
			[CreateDate]
		)
		select 
			a.ASXCode,
			a.ObservationDate,
			NetVolume,
			NetValue,
			TotalVolume,
			TotalValue,
			a.CreateDate
		from
		(
			select 
				ASXCode, 
				ObservationDate, 
				sum(NetVolume) as NetVolume, 
				sum(NetValue) as NetValue,
				cast(getdate() as date) as CreateDate
			from StockData.BrokerReport
			where NetVolume > 0
			group by ASXCode, ObservationDate
		) as a
		inner join
		(
			select 
				ASXCode, 
				ObservationDate, 
				cast(sum(TotalVolume)/2.0 as bigint) as TotalVolume,
				sum(BuyValue) as TotalValue,
				cast(getdate() as date) as CreateDate
			from StockData.BrokerReport
			where 1 = 1
			group by ASXCode, ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		where not exists
		(
			select 1
			from Transform.PriceHistoryNetVolume
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
		);
		
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
