-- Stored procedure: [StockData].[usp_GetFirstBuySell_Buy_dev]




create PROCEDURE [StockData].[usp_GetFirstBuySell_Buy_dev]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay int = 0, 
@pdtObservationDate date = null
AS
/******************************************************************************
File: usp_GetFirstBuySell.sql
Stored Procedure Name: usp_GetFirstBuySell
Overview
-----------------
usp_GetFirstBuySell

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_GetFirstBuySell]
@intNumPrevDay = 0, 
--@pdtObservationDate = '2023-11-09',
@pvchStockCode = 'FL1.AX',
@pbitDebug = 0

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetFirstBuySell'
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
		--declare @pdtObservationDate as date
		--declare @pintNumPrevDay as int = 1
		--declare @pvchStockCode as varchar(10) = 'GMD.AX'
		declare @dtEnqDate as date	
		
		if @pdtObservationDate is not null
		begin
			select @dtEnqDate = @pdtObservationDate
		end
		else
		begin
			select @dtEnqDate = [Common].[DateAddBusinessDay](-1 * @pintNumPrevDay, cast(getdate() as date))
		end	

		if object_id(N'Tempdb.dbo.#TempStockList') is not null
			drop table #TempStockList
		
		select 
			a.[ASXCode],
			substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode
		into #TempStockList
		from 
		(
			select ASXCode 
			from StockData.MonitorStock as a with(nolock)
			where MonitorTypeID in ('M', 'X')
			and isnull(PriorityLevel, 999) <= 199
			union
			select ASXCode
			from StockData.StockBidAskObservationTime as a
			where ASXCode is not null
			and ObservationDate = @pdtObservationDate
			union 
			select distinct ASXCode
			from StockData.StockBidAsk as a
			where ASXCode is not null
			and ObservationDate = @pdtObservationDate
		) as a 
		inner join Stock.ASXCompany as c
		on a.ASXCode = c.ASXCode
		and c.IsDisabled = 0
		and isnull(c.MarketCap, 1) < 5000000 
		and a.ASXCode not in ('14D.AX')

		declare @vchStockList as varchar(max)

		select @vchStockList = '''' + STRING_AGG(ASXCode, ''', ''') + ''''
		from #TempStockList

		--select @vchStockList 

		if object_id(N'Tempdb.dbo.#TempFirstBuySell') is not null
			drop table #TempFirstBuySell

		declare @nvchGenericQuery as nvarchar(max)

		select @nvchGenericQuery = '
		select 
			a.ASXCode,
			SaleDateTime as ObservationDateTime,
			format(SizeBid, ''N0'') as FormatBid1Volume,
			SizeBid as Bid1Volume,
			1 as Buy1NoOfOrder,
			PriceBid as Buy1Price,
			DateFrom as Buy1DateFrom,
			DateTo as Buy1DateTo,
			format(SizeAsk, ''N0'') as FormatAsk1Volume,
			SizeAsk as Ask1Volume,
			1 as Sell1NoOfOrder,
			PriceAsk as Sell1Price,
			DateFrom as Sell1DateFrom,
			DateTo as Sell1DateTo,
			Price as TransPrice,
			Quantity as TransQuantity,
			SaleValue as TransValue,
			DerivedBuySellInd as ActBuySellInd,
			Exchange as Exchange,
			cast(
				case when PriceAsk > PriceBid and SaleValue >= 15000 and (Price > PriceAsk) then ''B5''
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price < PriceBid) then ''S5''
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceAsk and Quantity > 2*SizeAsk and Quantity <= 3*SizeAsk) then ''B1''
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceBid and Quantity > 2*SizeBid and Quantity <= 3*SizeBid) then ''S1''		
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceAsk and Quantity > 3*SizeAsk) then ''B2''
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceBid and Quantity > 3*SizeBid) then ''S2''				 
					 else null
				end
			as varchar(10)) as DerivedInstitute,
			row_number() over (partition by ASXCode, SaleDateTime order by case when Price is not null then 1 else 0 end desc, DateFrom desc) as RowNumber
		into #TempFirstBuySell	
		from StockData.v_StockTickSaleVsBidAsk_All as a with(nolock)
		where ASXCode is not null
		and a.ObservationDate = ''' + cast(@dtEnqDate as varchar(50)) + '''
		and a.ASXCode in (' + @vchStockList +')
		order by SaleDateTime desc, DateFrom desc, DateTo desc
		option(recompile);
		
		delete a
		from #TempFirstBuySell as a
		where RowNumber > 1;

		select 
			   ''Strong Buy'' as ReportType
			  ,[ObservationDateTime]
			  ,a.ASXCode
			  ,cast([ObservationDateTime] as date) as ObservationDate
			  ,[FormatBid1Volume]
			  ,format(case when Buy1Price = PrevBuy1Price then a.Bid1Volume - a.PrevBid1Volume 
					when Buy1Price > PrevBuy1Price then a.Bid1Volume
					when Buy1Price < PrevBuy1Price then -1*a.PrevBid1Volume
			   end, ''N0'') as Bid1VolumeDelta
			  --,[Buy1NoOfOrder]
			  ,[Buy1Price]
			  ,cast([Buy1DateFrom] as time) as [Buy1DateFrom]
			  ,cast([Buy1DateTo] as time) as [Buy1DateTo]
			  ,[FormatAsk1Volume]
			  ,format(case when Sell1Price = PrevSell1Price then a.Ask1Volume - a.PrevAsk1Volume 
				 when Sell1Price > PrevSell1Price then -1*a.PrevAsk1Volume
				 when Sell1Price < PrevSell1Price then a.Ask1Volume
			   end, ''N0'') as Ask1VolumeDelta
			  --,[Sell1NoOfOrder]
			  ,[Sell1Price]
			  ,cast([Sell1DateFrom] as time) as [Sell1DateFrom]
			  ,cast([Sell1DateTo] as time) as [Sell1DateTo]
			  ,[TransPrice]
			  ,[TransQuantity]
			  ,[TransValue]
			  ,[ActBuySellInd]
			  --,[Exchange]
			  ,[DerivedInstitute]
		into #TempPriceBidAsk
		from
		(
			select 
				*, 
				lag(Bid1Volume) over (partition by ASXCode order by ObservationDateTime) as PrevBid1Volume,
				lag(Buy1Price) over (partition by ASXCode order by ObservationDateTime) as PrevBuy1Price,
				lag(Ask1Volume) over (partition by ASXCode order by ObservationDateTime) as PrevAsk1Volume,
				lag(Sell1Price) over (partition by ASXCode order by ObservationDateTime) as PrevSell1Price
			from #TempFirstBuySell
		) as a
		where 1 = 1
		and left(DerivedInstitute, 1) in (''B'', ''S'')
		--and DerivedInstitute in (''B5'')
		order by a.ASXCode, ObservationDateTime desc, Buy1DateFrom desc, Sell1DateFrom desc;
		
	
		select 
				x.ReportType,
				x.ObservationDateTime as LatestBuyDateTime,
				x.ASXCode, 
				x.ObservationDate,
				x.NumTrans as BuyNumTrans,
				x.AvgTransPrice as BuyAvgTransPrice,
				x.TotalValue as BuyTotalValue,
				x.TotalQuantity as BuyTotalQuantity,
				x.DerivedInstitute as BuyCode,
				''---'' as Separator,
				y.ObservationDateTime as LatestSellDateTime,
				y.NumTrans as SellNumTrans,
				y.AvgTransPrice as SellAvgTransPrice,
				y.TotalValue as SellTotalValue,
				y.TotalQuantity as SellTotalQuantity,
				y.DerivedInstitute as SellCode
		from
		(
			select
				ReportType,
				max(ObservationDateTime) as ObservationDateTime,
				ASXCode, 
				ObservationDate,
				count(*) as NumTrans,
				cast(sum(TransPrice*TransQuantity)*1.0/sum(TransQuantity) as decimal(10, 4)) as AvgTransPrice,
				format(sum(TransPrice*TransQuantity), ''N0'') as TotalValue,
				format(sum(TransQuantity), ''N0'') as TotalQuantity,
				DerivedInstitute
			from #TempPriceBidAsk as a
			where left(DerivedInstitute, 1) in (''B'')
			group by ReportType, ASXCode, ObservationDate, DerivedInstitute
			--order by DerivedInstitute desc, max(ObservationDateTime) desc, count(*) desc, ASXCode 
		) as x
		left join
		(
			select
				ReportType,
				max(ObservationDateTime) as ObservationDateTime,
				ASXCode, 
				ObservationDate,
				count(*) as NumTrans,
				cast(sum(TransPrice*TransQuantity)*1.0/sum(TransQuantity) as decimal(10, 4)) as AvgTransPrice,
				format(sum(TransPrice*TransQuantity), ''N0'') as TotalValue,
				format(sum(TransQuantity), ''N0'') as TotalQuantity,
				DerivedInstitute
			from #TempPriceBidAsk as a
			where left(DerivedInstitute, 1) in (''S'')
			group by ReportType, ASXCode, ObservationDate, DerivedInstitute
			--order by DerivedInstitute desc, max(ObservationDateTime) desc, count(*) desc, ASXCode 
		) as y
		on x.ASXCode = y.ASXCode
		and substring(x.DerivedInstitute, 2, 1) = substring(y.DerivedInstitute, 2, 1)
		and x.ObservationDate = y.ObservationDate
		order by x.DerivedInstitute desc, x.ObservationDateTime desc, x.NumTrans desc, x.ASXCode 
		
		'
		--exec Utility.usp_LongPrint @nvchGenericQuery
		exec sp_executesql @nvchGenericQuery


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
