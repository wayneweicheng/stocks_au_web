-- Stored procedure: [Report].[usp_GetPropectFromMoneyFlowAnalysis]



CREATE PROCEDURE [Report].[usp_GetPropectFromMoneyFlowAnalysis]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetPropectFromMoneyFlowAnalysis.sql
Stored Procedure Name: usp_GetPropectFromMoneyFlowAnalysis
Overview
-----------------
usp_GetPropectFromMoneyFlowAnalysis

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
Date:		2019-05-25
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetPropectFromMoneyFlowAnalysis'
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
		--declare @pintNumPrevDay as int = 0
		select 
		a.[Close], c.[Close],
		(cast(a.[Close] as decimal(20, 4)) - cast(c.[Close] as decimal(20, 4)))/cast(c.[Close] as decimal(20, 4)), 
		b.AvgMoneyFlowAmount, a.*
		from StockData.MoneyFlowInOutHistory as a
		inner join
		(
			select ASXCode, avg(MoneyFlowAmountIn + MoneyFlowAmountOut) as AvgMoneyFlowAmount 
			from StockData.MoneyFlowInOutHistory
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.MoneyFlowAmountOut > 1.5*b.AvgMoneyFlowAmount
		and a.MoneyFlowAmountOut > 1.5*a.MoneyFlowAmountIn
		and a.MoneyFlowAmountOut < 5*a.MoneyFlowAmountIn
		and a.[Close] > a.VWAP
		inner join StockData.MoneyFlowInOutHistory as c
		on a.ASXCode = c.ASXCode
		and a.RowNumber + 1 = c.RowNumber
		and (cast(a.[Close] as decimal(20, 4)) - cast(c.[Close] as decimal(20, 4)))/cast(c.[Close] as decimal(20, 4)) > - 0.04
		where a.MarketDate = cast(getdate() as date)
		order by a.MarketDate desc

		select 
		--a.[Close], c.[Close],
		--(cast(a.[Close] as decimal(20, 4)) - cast(c.[Close] as decimal(20, 4)))/cast(c.[Close] as decimal(20, 4)), 
		a.MoneyFlowAmountIn,
		c.MoneyFlowAmountIn,
		b.AvgMoneyFlowAmount, 
		a.*
		from StockData.MoneyFlowInOutHistory as a
		inner join
		(
			select ASXCode, avg(MoneyFlowAmountIn + MoneyFlowAmountOut) as AvgMoneyFlowAmount 
			from StockData.MoneyFlowInOutHistory
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.MoneyFlowAmountIn > 1*b.AvgMoneyFlowAmount
		--and a.MoneyFlowAmountOut > 1.5*a.MoneyFlowAmountIn
		--and a.MoneyFlowAmountOut < 5*a.MoneyFlowAmountIn
		inner join StockData.MoneyFlowInOutHistory as c
		on a.ASXCode = c.ASXCode
		and a.RowNumber + 1 = c.RowNumber
		and c.MoneyFlowAmountIn > 0.8*b.AvgMoneyFlowAmount
		and c.MoneyFlowAmountIn > 1.2*c.MoneyFlowAmountOut
		and c.MoneyFlowAmountIn < 2.5*c.MoneyFlowAmountOut
		and c.[Close] < c.VWAP
		and a.[Close] > c.VWAP
		inner join StockData.MoneyFlowInOutHistory as d
		on c.ASXCode = d.ASXCode
		and c.RowNumber + 3 = d.RowNumber
		and c.[VWAP] < d.[VWAP]
		--and (cast(a.[Close] as decimal(20, 4)) - cast(c.[Close] as decimal(20, 4)))/cast(c.[Close] as decimal(20, 4)) > - 0.04
		--and a.ASXCode = 'AMI.AX'


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
