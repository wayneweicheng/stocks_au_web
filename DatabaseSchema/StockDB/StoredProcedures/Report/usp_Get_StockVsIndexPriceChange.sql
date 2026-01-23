-- Stored procedure: [Report].[usp_Get_StockVsIndexPriceChange]



CREATE PROCEDURE [Report].[usp_Get_StockVsIndexPriceChange]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10),
@pvchIndex as varchar(10)
AS
/******************************************************************************
File: usp_Get_StockVsIndexPriceChange.sql
Stored Procedure Name: usp_Get_StockVsIndexPriceChange
Overview
-----------------
usp_Get_StockVsIndexPriceChange

Input Parameters
----------------
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
Date:		2021-12-20
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_StockVsIndexPriceChange'
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
		--declare @pvchStockCode as varchar(10) = 'LKE.AX'
		--declare @pintNumPrevDay as int = 0
		select *, lag([Close], 1, null) over (order by ObservationDate asc) as PrevClose, cast(null as decimal(20, 2)) as ChangePerc
		into #Temp
		from StockData.PriceHistory
		where ASXCode = @pvchIndex

		update a
		set ChangePerc = ([Close] - [PrevClose])*100.0/[PrevClose]
		from #Temp as a
		where [PrevClose] > 0

		select *, lag([Close], 1, null) over (order by ObservationDate asc) as PrevClose, cast(null as decimal(20, 2)) as ChangePerc, cast(null as decimal(20, 2)) as ChangePercVsOpen
		into #Temp2
		from StockData.PriceHistory as a
		where ASXCode = @pvchStockCode
		and exists
		(
			select 1
			from StockData.MedianTradeValue
			where ASXCode = a.ASXCode
			and MedianTradeValue > 1000
			and MedianPriceChangePerc > 0.9
		)

		update a
		set ChangePerc = ([Close] - [PrevClose])*100.0/[PrevClose]
		from #Temp2 as a
		where [PrevClose] > 0

		update a
		set ChangePercVsOpen = ([Close] - [Open])*100.0/[Open]
		from #Temp2 as a
		where [Open] > 0

		select 
			a.ASXCode as IndexCode, 
			b.ASXCode, b.ObservationDate, 
			a.ChangePerc as IndexChangePerc, 
			b.ChangePerc as StockChangePerc,
			b.ChangePercVsOpen as StockChangePercVsOpen
		from #Temp as a
		inner join #Temp2 as b
		on a.ObservationDate = Common.DateAddBusinessDay(-1, b.ObservationDate)
		where a.ChangePerc is not null
		and b.ChangePerc is not null		

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