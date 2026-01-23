-- Stored procedure: [StockAPI].[usp_GetUSTradeSymbol]

CREATE PROCEDURE [StockAPI].[usp_GetUSTradeSymbol]
@pbitDebug AS BIT = 0, 
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetUSTradeSymbol.sql
Stored Procedure Name: usp_GetUSTradeSymbol
Overview
-----------------
usp_GetUSTradeSymbol

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
Date:		2023-10-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetUSTradeSymbol'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		select ASXCode
		from
		(
			select ASXCode
			from StockDB_US.Stock.ETF as a
			union
			select ASXCode
			from StockDB_US.StockData.CompanyInfo
			union
			select ASXCode
			from StockDB_US.StockData.QU100Parsed
			union
			select
				[ASXCode]
			from
			(
				select 'M2K_20241220.US' as ASXCode
				union
				select 'MES_20241220.US' as ASXCode
				union
				select 'MNQ_20241220.US' as ASXCode
				union
				select 'VIX_20241218.US' as ASXCode
				union
				select 'XAUUSD' as ASXCode
				union
				select 'IBUS500' as ASXCode
				union
				select 'IBUS100' as ASXCode
				union
				select 'IBUS30' as ASXCode
				union
				select 'GOLD.US' as ASXCode
				union
				select 'AAPL.US' as ASXCode
				union
				select 'TSLA.US' as ASXCode
				union
				select 'MSFT.US' as ASXCode
				union
				select 'NVDA.US' as ASXCode
				union
				select 'GDX.US' as ASXCode
				union
				select 'GLD.US' as ASXCode
				union
				select 'TLT.US' as ASXCode
			) as i
		) as x
		order by 
			case when ASXCode = 'QQQ.US' then 10
				 when ASXCode = 'SPY.US' then 15
				when ASXCode = 'TQQQ.US' then 20
				when ASXCode = 'SQQQ.US' then 25
				when ASXCode = 'SPXL.US' then 30
				when ASXCode = 'SPXS.US' then 35
				when ASXCode = 'TSLA.US' then 40
				when ASXCode = 'NVDA.US' then 45
				when ASXCode = 'APPL.US' then 50
				when ASXCode = 'TLT.US' then 55
				when ASXCode = 'DIA.US' then 60
				when ASXCode = 'IWM.US' then 60
				else 9999
			end asc, 
			ASXCode


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