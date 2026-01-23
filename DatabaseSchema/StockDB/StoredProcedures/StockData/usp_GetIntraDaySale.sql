-- Stored procedure: [StockData].[usp_GetIntraDaySale]






CREATE PROCEDURE [StockData].[usp_GetIntraDaySale]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pdtObservationDate smalldatetime = null, 
--@pdtObservationDate date = '2016-05-19',
@pvchStockCode varchar(20)
AS
/******************************************************************************
File: usp_GetIntraDaySale.sql
Stored Procedure Name: usp_GetIntraDaySale
Overview
-----------------
usp_GetIntraDaySale

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
Date:		2016-08-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIntraDaySale'
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
		if @pdtObservationDate is null
		begin
			select @pdtObservationDate = getdate()
		end
		
		--declare @pvchStockCode as varchar(20) = 'ADA.AX'
		--declare @pdtObservationDate as date = '2016-08-12'

		declare @bitSaleUpToDate as bit = 0

		if exists(
			select 1
			from [StockData].[MonitorStock]
			where ASXCode = @pvchStockCode
			and datediff(second, [LastUpdateDate], getdate()) < 1800
			and MonitorTypeID = 'C'
		) or
		   exists(
		   select 1
		   from StockData.PriceSummaryToday
		   where ASXCode = @pvchStockCode
		   and LastVerifiedDate > @pdtObservationDate
		   and cast(DateFrom as date) = cast(@pdtObservationDate as date)
		)
			select @bitSaleUpToDate = 1
		else
			select @bitSaleUpToDate = 0

		select 
			x.ASXCode,
			x.MinPrice,
			x.MaxPrice,
			x.Quantity,
			OpenPrice as OpenPrice,
			ClosePrice as ClosePrice,
			convert(varchar(30), @pdtObservationDate, 103) as TodayDate
		from
		(
			select 
				ASXCode,
				Low as MinPrice,
				High as MaxPrice,
				Volume as Quantity,
				[Open] as OpenPrice,
				[Close] as ClosePrice,
				row_number() over (partition by ASXCode order by LastVerifiedDate desc) as RowNumber
			from StockData.PriceSummaryToday as a
			where ASXCode = @pvchStockCode
			and cast(DateFrom as date) = cast(@pdtObservationDate as date)
			and LastVerifiedDate < dateadd(minute, 30, @pdtObservationDate)
		) as x
		where x.RowNumber = 1
		and @bitSaleUpToDate = 1

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
