-- Stored procedure: [StockData].[usp_AddPriceHistory]






CREATE PROCEDURE [StockData].[usp_AddPriceHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchPriceHistory as varchar(max),
@pvchDateTime as varchar(100)
AS
/******************************************************************************
File: usp_AddPriceHistory.sql
Stored Procedure Name: usp_AddPriceHistory
Overview
-----------------
usp_AddPriceHistory

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
Date:		2017-06-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddPriceHistory'
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
		--begin transaction
		
		--@pxmlMarketDepth

		--declare @pvchDateTime as varchar(100) = '10 Aug 11:49:16 PM'

		declare @vchModifiedDateTime as varchar(100) = left(@pvchDateTime, 7) + cast(year(getdate()) as varchar(4)) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 2) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 1)

		--select convert(smalldatetime, @vchModifiedDateTime, 113)

		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		select
			30 as DataTypeID,
			@pvchPriceHistory as RawData,
			getdate() as CreateDate,
			convert(datetime, @vchModifiedDateTime, 113) as SourceSystemDate
		
		declare @vchStockCode as varchar(20)
		declare @xmlPriceHistory as xml
		--select @xmlMarketDepth = cast(RawData as xml) from StockData.RawData
		--where RawDataID = 9
		select @xmlPriceHistory = cast(@pvchPriceHistory as xml)

		select @vchStockCode = @xmlPriceHistory.value('(/PriceHistory/stockCode)[1]', 'varchar(20)')

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		select 
			x.si.value('date[1]', 'varchar(100)') as [ObservationDate],
			x.si.value('open[1]', 'varchar(100)') as [open],
			x.si.value('high[1]', 'varchar(100)') as [high],
			x.si.value('low[1]', 'varchar(100)') as [low],
			x.si.value('close[1]', 'varchar(100)') as [close],
			x.si.value('volume[1]', 'varchar(100)') as volume,
			x.si.value('value[1]', 'varchar(100)') as value,
			x.si.value('trades[1]', 'varchar(100)') as trades
		into #TempPriceHistory
		from @xmlPriceHistory.nodes('/PriceHistory/priceHistory/PriceItem') as x(si)

		set dateformat dmy

		insert into StockData.PriceHistory
		(
			[ASXCode],
			[ObservationDate],
			[Close],
			[Open],
			[Low],
			[High],
			[Volume],
			[Value],
			[Trades],
			CreateDate,
			ModifyDate
		)
		select
			@vchStockCode as [ASXCode],
			[ObservationDate],
			[Close],
			[Open],
			[Low],
			[High],
			[Volume],
			[Value],
			[Trades],
			convert(datetime, @vchModifiedDateTime, 113) as CreateDate,	
			convert(datetime, @vchModifiedDateTime, 113) as ModifiedDate	
		from #TempPriceHistory as a
		where not exists
		(
			select 1
			from StockData.PriceHistory
			where ObservationDate = cast(a.ObservationDate as date)
			and ASXCode = @vchStockCode
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
