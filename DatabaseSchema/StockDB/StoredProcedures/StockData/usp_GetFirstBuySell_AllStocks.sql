-- Stored procedure: [StockData].[usp_GetFirstBuySell_AllStocks]



CREATE PROCEDURE [StockData].[usp_GetFirstBuySell_AllStocks]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetFirstBuySell_AllStocks.sql
Stored Procedure Name: usp_GetFirstBuySell_AllStocks
Overview
-----------------
usp_GetFirstBuySell_AllStocks

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
Date:		2018-04-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetFirstBuySell_AllStocks'
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
		--declare @pbitDebug as bit = 0
		--declare @intNumPrevDay as int = 1
		--declare @pvchStockCode as varchar(10) = 'SYA.AX'
		if object_id(N'Tempdb.dbo.#TempFirstBuySell') is not null
			drop table #TempFirstBuySell

		select 
			a.ASXCode,
			a.ObservationDate,
			SaleDateTime as ObservationDateTime,
			format(SizeBid, 'N0') as FormatBid1Volume,
			SizeBid as Bid1Volume,
			1 as Buy1NoOfOrder,
			PriceBid as Buy1Price,
			DateFrom as Buy1DateFrom,
			DateTo as Buy1DateTo,
			format(SizeAsk, 'N0') as FormatAsk1Volume,
			SizeAsk as Ask1Volume,
			1 as Sell1NoOfOrder,
			PriceAsk as Sell1Price,
			DateFrom as Sell1DateFrom,
			DateTo as Sell1DateTo,
			Price as TransPrice,
			format(Quantity, 'N0') as TransQuantity,
			format(SaleValue, 'N0') as TransValue,
			DerivedBuySellInd as ActBuySellInd,
			Exchange as Exchange,
			DerivedInstitute as DerivedInstitute	
		into #TempFirstBuySell	
		from StockData.v_StockTickSaleVsBidAsk_All as a with(nolock)
		where ASXCode is not null
		and a.ObservationDate >= dateadd(day, -30, getdate())
		order by SaleDateTime desc, DateFrom desc, DateTo desc
		option(recompile);

		select 
			   ASXCode
			  ,ObservationDate
			  ,[ObservationDateTime]
			  ,[FormatBid1Volume]
			  ,format(case when Buy1Price = PrevBuy1Price then a.Bid1Volume - a.PrevBid1Volume 
					when Buy1Price > PrevBuy1Price then a.Bid1Volume
					when Buy1Price < PrevBuy1Price then -1*a.PrevBid1Volume
			   end, 'N0') as Bid1VolumeDelta
			  ,[Buy1NoOfOrder]
			  ,[Buy1Price]
			  ,cast([Buy1DateFrom] as time) as [Buy1DateFrom]
			  ,cast([Buy1DateTo] as time) as [Buy1DateTo]
			  ,[FormatAsk1Volume]
			  ,format(case when Sell1Price = PrevSell1Price then a.Ask1Volume - a.PrevAsk1Volume 
				 when Sell1Price > PrevSell1Price then -1*a.PrevAsk1Volume
				 when Sell1Price < PrevSell1Price then a.Ask1Volume
			   end, 'N0') as Ask1VolumeDelta
			  ,[Sell1NoOfOrder]
			  ,[Sell1Price]
			  ,cast([Sell1DateFrom] as time) as [Sell1DateFrom]
			  ,cast([Sell1DateTo] as time) as [Sell1DateTo]
			  ,[TransPrice]
			  ,[TransQuantity]
			  ,[TransValue]
			  ,[ActBuySellInd]
			  --,[Exchange]
			  ,[DerivedInstitute]
		from
		(
			select 
				*, 
				lag(Bid1Volume) over (order by ObservationDateTime) as PrevBid1Volume,
				lag(Buy1Price) over (order by ObservationDateTime) as PrevBuy1Price,
				lag(Ask1Volume) over (order by ObservationDateTime) as PrevAsk1Volume,
				lag(Sell1Price) over (order by ObservationDateTime) as PrevSell1Price
			from #TempFirstBuySell
		) as a
		order by ObservationDateTime desc, Buy1DateFrom desc, Sell1DateFrom desc		

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
