-- Stored procedure: [StockData].[usp_RefeshStockCustomFilter]






CREATE PROCEDURE [StockData].[usp_RefeshStockCustomFilter]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pbitMonitorStockUpdateOnly bit = 0
AS
/******************************************************************************
File: usp_RefeshStockCustomFilter.sql
Stored Procedure Name: usp_RefeshStockCustomFilter
Overview
-----------------
usp_RefeshStockCustomFilter

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
Date:		2020-11-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshStockCustomFilter'
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
		if @pbitMonitorStockUpdateOnly = 0
		begin
			if object_id(N'StockData.CustomFilter') is not null
				drop table StockData.CustomFilter

			CREATE TABLE [StockData].[CustomFilter](
				[CustomFilterID] int identity(1, 1) not null,
				[CustomFilter] [varchar](500) not NULL,
				[DisplayOrder] [int] not NULL,
				CreateDate smalldatetime
			)
		end
		else
		begin
			delete a
			from [StockData].[CustomFilterDetail] as a
			inner join [StockData].[CustomFilter] as b
			on a.CustomFilterID = b.CustomFilterID
			where CustomFilter in ('Monitor Stock - Core Stocks', 'Monitor Stock - All Stocks')
		end

		if @pbitMonitorStockUpdateOnly = 0
		begin		
			insert into [StockData].[CustomFilter]
			(
				[CustomFilter],
				[DisplayOrder],
				CreateDate
			)
			select distinct
				[CustomFilter],
				[DisplayOrder],
				getdate() as CreateDate
			from
			(
				select 'Monitor Stock - Core Stocks' as CustomFilter, 100 as DisplayOrder
				union
				select 'Monitor Stock - All Stocks' as CustomFilter, 120 as DisplayOrder
				union
				select 'Trade Strategy - Volume Volatility Contraction' as CustomFilter, 250 as Display
				union
				select 'Trade Strategy - Long Bullish Bar' as CustomFilter, 240 as Display
				union
				select 'Trade Strategy - Break Through Previous Break Through High' as CustomFilter, 230 as Display
				union
				select 'Trade Strategy - Broker New Buy Report' as CustomFilter, 210 as Display
				union
				select 'Trade Strategy - Broker Buy Retail Sell' as CustomFilter, 220 as Display
				union
				select 'Trade Strategy - Today Close Cross Over VWAP' as CustomFilter, 260 as Display
				union
				select 'Scan Results - Alert Occurrence Current Date' as CustomFilter, 300 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 1 Day' as CustomFilter, 310 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 2 Day' as CustomFilter, 320 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 3 Day' as CustomFilter, 330 as Display
				union
				select 'Others - Director Buy On Market' as CustomFilter, 800 as Display
				union
				select distinct 'Sector - ' + upper(Token) as CustomFilter, 
								800 + TokenOrder as DisplayOrder
				from LookupRef.KeyToken
				where isnull(IsDisabled, 0) = 0
				and TokenType = 'Sector'
			) as a
			order by DisplayOrder		

			if object_id(N'StockData.CustomFilterDetail') is not null
				drop table StockData.CustomFilterDetail

			CREATE TABLE [StockData].[CustomFilterDetail](
				[CustomFilterDetailID] int identity(1, 1) not null,
				[CustomFilterID] int not null,
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				CreateDate smalldatetime
			)

			if object_id(N'Tempdb.dbo.#TempBrokerNewBuy') is not null
				drop table #TempBrokerNewBuy

			create table #TempBrokerNewBuy
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null
			)

			insert into #TempBrokerNewBuy
			exec [Report].[usp_Get_Strategy_BrokerNewBuy]
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempBrokerBuyRetailSell') is not null
				drop table #TempBrokerBuyRetailSell

			create table #TempBrokerBuyRetailSell
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null
			)

			insert into #TempBrokerBuyRetailSell
			exec [Report].[usp_Get_Strategy_BrokerBuy]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempBreakThroughPreviousHigh') is not null
				drop table #TempBreakThroughPreviousHigh

			create table #TempBreakThroughPreviousHigh
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null
			)

			insert into #TempBreakThroughPreviousHigh
			exec [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			insert into StockData.CustomFilterDetail
			(
				[CustomFilterID],
				ASXCode,
				DisplayOrder,
				CreateDate
			)
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and isnull(PriorityLevel, 999) <= 999
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - Core Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - All Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBrokerNewBuy
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Broker New Buy Report'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBrokerBuyRetailSell
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Broker Buy Retail Sell'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBreakThroughPreviousHigh
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Break Through Previous Break Through High'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					a.Token,
					b.TokenOrder as DisplayOrder
				from LookupRef.StockKeyToken as a
				inner join LookupRef.KeyToken as b
				on a.Token = b.Token
				and b.TokenType = 'SECTOR'
			) as b
			on a.CustomFilter = 'Sector - ' + b.Token
			where CustomFilter like 'Sector - %'
		end
		else
		begin
			insert into StockData.CustomFilterDetail
			(
				[CustomFilterID],
				ASXCode,
				DisplayOrder,
				CreateDate
			)
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and isnull(PriorityLevel, 999) <= 999
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - Core Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - All Stocks'
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
