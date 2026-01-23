-- Stored procedure: [StockData].[usp_AddStockTip]



CREATE PROCEDURE [StockData].[usp_AddStockTip]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTipUser varchar(200), 
@pvchTipUserId varchar(50), 
@pvchASXCode varchar(10), 
@pvchTipType varchar(50), 
@pdtTipTime smalldatetime, 
@pvchAdditionalNotes varchar(2000), 
@pvchCreatedBy varchar(200), 
@pvchCreatedByUserId varchar(50), 
@pvchOutputMessage varchar(2000) output
AS
/******************************************************************************
File: usp_AddStockTip.sql
Stored Procedure Name: usp_AddStockTip
Overview
-----------------
usp_AddStockTip

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
Date:		2022-11-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddStockTip'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchObservationDate as varchar(20) = '20220617'
		
		--Code goes here 

		set dateformat ymd

		if object_id(N'Tempdb.dbo.#TempStockTip') is not null
			drop table #TempStockTip

		select
			upper(@pvchASXCode) as ASXCode,
			@pvchTipUser as TipUser,
			@pvchTipUserId as TipUserId,
			@pvchTipType as TipType,
			@pdtTipTime as TipDateTime,
			@pvchAdditionalNotes as AdditionalNotes,
			@pvchCreatedBy as CreatedBy,
			@pvchCreatedByUserId as CreatedByUserId,
			getdate() as CreateDateTime
		into #TempStockTip

		if exists(
			select 1
			from #TempStockTip as a
			where exists
			(
				select 1
				from StockData.StockTip
				where ASXCode = @pvchASXCode
				and TipType = @pvchTipType
				and TipUser = @pvchTipUser
				and TipDateTime = @pdtTipTime
			)
		)
		begin
			update a
			set a.AdditionalNotes = b.AdditionalNotes
			from StockData.StockTip as a
			inner join #TempStockTip as b
			on a.ASXCode = b.ASXCode
			and a.TipUser = b.TipUser
			and a.TipDateTime = b.TipDateTime
			and a.TipType = b.TipType
			where a.ASXCode = @pvchASXCode

			select @pvchOutputMessage = @pvchTipType + ' tip is updated successfully ' + '- ' + @pvchASXCode
		end
		else
		begin
			insert into StockData.StockTip
			(
			   [TipUser]
			  ,[TipUserId]
			  ,[ASXCode]
			  ,[TipType]
			  ,[TipDateTime]
			  ,[AdditionalNotes]
			  ,[CreatedBy]
			  ,[CreatedByUserId]
			  ,[CreateDateTime]
			)
			select
			   [TipUser]
			  ,[TipUserId]
			  ,[ASXCode]
			  ,[TipType]
			  ,[TipDateTime]
			  ,[AdditionalNotes]
			  ,[CreatedBy]
			  ,[CreatedByUserId]
			  ,[CreateDateTime]
			from #TempStockTip

			if right(@pvchASXCode, 3) = '.US'
			begin
				update a
				set a.PriceAsAtTip = b.[Close]
				from StockData.StockTip as a
				inner join StockDB_US.StockData.PriceHistory as b with(nolock)
				on a.ASXCode = b.ASXCode
				and b.ObservationDate = cast(CONVERT(datetime,a.TipDateTime) AT TIME ZONE 'Aus Eastern Standard Time' AT TIME ZONE 'US Eastern Standard Time' as date)
				where a.PriceAsAtTip is null
			end
			else
			begin
				update a
				set a.PriceAsAtTip = b.[Close]
				from StockData.StockTip as a
				inner join StockData.v_PriceSummary as b with(nolock)
				on a.ASXCode = b.ASXCode
				and a.TipDateTime >= b.DateFrom 
				and a.TipDateTime < b.DateTo
				and b.ObservationDate = cast(a.TipDateTime as date)
				and cast(a.TipDateTime as time) < cast('16:11:00' as time)
				and cast(a.TipDateTime as time) >= cast('09:59:00' as time)
				where a.PriceAsAtTip is null

				update a
				set a.PriceAsAtTip = b.[Open]
				from StockData.StockTip as a
				inner join StockData.PriceHistory as b with(nolock)
				on a.ASXCode = b.ASXCode
				and b.ObservationDate = Common.DateAddBusinessDay(1, cast(a.TipDateTime as date)) 
				and cast(a.TipDateTime as time) > cast('16:11:00' as time)
				where a.PriceAsAtTip is null

				update a
				set a.PriceAsAtTip = b.[Open]
				from StockData.StockTip as a
				inner join StockData.PriceHistory as b with(nolock)
				on a.ASXCode = b.ASXCode
				and b.ObservationDate = Common.DateAddBusinessDay(0, cast(a.TipDateTime as date)) 
				and cast(a.TipDateTime as time) < cast('09:59:00' as time)
				where a.PriceAsAtTip is null

				update a
				set a.PriceAsAtTip = b.[Close]
				from StockData.StockTip as a
				inner join StockData.PriceHistory as b with(nolock)
				on a.ASXCode = b.ASXCode
				and b.ObservationDate = cast(a.TipDateTime as date)
				where a.PriceAsAtTip is null
			end
			
			select @pvchOutputMessage = @pvchTipType + ' tip is added successfully ' + '- ' + @pvchASXCode  
		end
		
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
