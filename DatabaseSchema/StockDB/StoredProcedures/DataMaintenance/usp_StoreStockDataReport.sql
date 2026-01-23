-- Stored procedure: [DataMaintenance].[usp_StoreStockDataReport]



CREATE PROCEDURE [DataMaintenance].[usp_StoreStockDataReport]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_StoredStockDataReport.sql
Stored Procedure Name: usp_StoredStockDataReport
Overview
-----------------
usp_StoredStockDataReport

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
Date:		2020-10-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_StoredStockDataReport'
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
		if object_id(N'Tempdb.dbo.#TempStockInsight') is not null
			drop table #TempStockInsight

		CREATE TABLE #TempStockInsight(
			[ASXCode] [varchar](10) NOT NULL,
			[MC] [decimal](20, 2) NULL,
			[TotalSharesIssued] [decimal](10, 2) NULL,
			[FloatingShares] [decimal](20, 2) NULL,
			[FloatingSharesPerc] [decimal](10, 2) NULL,
			[CashPosition] [decimal](8, 2) NULL,
			[RecentTopBuyBroker] [nvarchar](max) NULL,
			[RecentTopSellBroker] [nvarchar](max) NULL,
			[FriendlyNameList] [nvarchar](max) NULL,
			MovingAverage5d decimal(20, 4),
			T1MovingAverage5d decimal(20, 4),
			MovingAverage10d decimal(20, 4),
			T1MovingAverage10d decimal(20, 4),
			[MedianTradeValueWeekly] [int] NULL,
			[MedianTradeValueDaily] [int] NULL,
			[MedianPriceChangePerc] [decimal](10, 2) NULL,
			[RelativePriceStrength] [decimal](10, 2) NULL,
			[FurtherDetails] [varchar](2000) NULL,
			[IndustryGroup] [varchar](200) NULL,
			[IndustrySubGroup] [varchar](200) NULL,
			[MediumTermRetailParticipationRate] [decimal](10, 2) NULL,
			[ShortTermRetailParticipationRate] [decimal](10, 2) NULL,
			[LastValidateDate] [smalldatetime] NULL
		)
		
		insert into #TempStockInsight
		exec [Report].[usp_GetMCvsCashPosition]

		delete a
		from [Transform].[StockInsight] as a
		where cast(CreateDate as date) = cast(getdate() as date)

		insert into [Transform].[StockInsight]
		(
		   [ASXCode]
		  ,[MC]
		  ,[TotalSharesIssued]
		  ,[FloatingShares]
		  ,[FloatingSharesPerc]
		  ,[CashPosition]
		  ,[RecentTopBuyBroker]
		  ,[RecentTopSellBroker]
		  ,[FriendlyNameList]
		  ,MovingAverage5d
		  ,T1MovingAverage5d
		  ,MovingAverage10d
		  ,T1MovingAverage10d
		  ,[MedianTradeValueWeekly]
		  ,[MedianTradeValueDaily]
		  ,[MedianPriceChangePerc]
		  ,[RelativePriceStrength]
		  ,[FurtherDetails]
		  ,[IndustryGroup]
		  ,[IndustrySubGroup]
		  ,[MediumTermRetailParticipationRate]
		  ,[ShortTermRetailParticipationRate]
		  ,[LastValidateDate]
		  ,CreateDate
		)
		select
		   [ASXCode]
		  ,[MC]
		  ,[TotalSharesIssued]
		  ,[FloatingShares]
		  ,[FloatingSharesPerc]
		  ,[CashPosition]
		  ,[RecentTopBuyBroker]
		  ,[RecentTopSellBroker]
		  ,[FriendlyNameList]
		  ,MovingAverage5d
		  ,T1MovingAverage5d
		  ,MovingAverage10d
		  ,T1MovingAverage10d
		  ,[MedianTradeValueWeekly]
		  ,[MedianTradeValueDaily]
		  ,[MedianPriceChangePerc]
		  ,[RelativePriceStrength]
		  ,[FurtherDetails]
		  ,[IndustryGroup]
		  ,[IndustrySubGroup]
		  ,[MediumTermRetailParticipationRate]
		  ,[ShortTermRetailParticipationRate]
		  ,[LastValidateDate]
		  ,getdate() as CreateDate
		from #TempStockInsight

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
