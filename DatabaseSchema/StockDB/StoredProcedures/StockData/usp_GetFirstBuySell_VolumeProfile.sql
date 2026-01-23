-- Stored procedure: [StockData].[usp_GetFirstBuySell_VolumeProfile]




CREATE PROCEDURE [StockData].[usp_GetFirstBuySell_VolumeProfile]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay int = 0, 
@pdtObservationDate date = null,
@pvchStockCode varchar(20) = null,
@pbitCreateTable bit = 1
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
		--declare @intNumPrevDay as int = 1
		--declare @pvchStockCode as varchar(10) = null
		declare @dtEnqDate as date	
		
		if @pdtObservationDate is not null
		begin
			select @dtEnqDate = @pdtObservationDate
		end
		else
		begin
			select @dtEnqDate = [Common].[DateAddBusinessDay](-1 * @intNumPrevDay, cast(getdate() as date))
		end		

		if object_id(N'Tempdb.dbo.#TempFirstBuySell') is not null
			drop table #TempFirstBuySell

		if object_id(N'Tempdb.dbo.#TempPriceBidAsk') is not null
			drop table #TempPriceBidAsk

		select 
			ASXCode,
			cast(SaleDateTime as date) as ObservationDate,
			SaleDateTime as ObservationDateTime,
			SizeBid as FormatBid1Volume,
			SizeBid as Bid1Volume,
			1 as Buy1NoOfOrder,
			PriceBid as Buy1Price,
			DateFrom as Buy1DateFrom,
			DateTo as Buy1DateTo,
			SizeAsk as FormatAsk1Volume,
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
				case when PriceAsk > PriceBid and SaleValue >= 15000 and (Price > PriceAsk) then 'B5'
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price < PriceBid) then 'S5'
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceAsk and Quantity > 2*SizeAsk and Quantity <= 3*SizeAsk) then 'B1'
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceBid and Quantity > 2*SizeBid and Quantity <= 3*SizeBid) then 'S1'		
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceAsk and Quantity > 3*SizeAsk) then 'B2'
					 when PriceAsk > PriceBid and SaleValue >= 15000 and (Price = PriceBid and Quantity > 3*SizeBid) then 'S2'				 
					 else null
				end
			as varchar(10)) as DerivedInstitute,
			row_number() over (partition by ASXCode, SaleDateTime order by case when Price is not null then 1 else 0 end desc, DateFrom desc) as RowNumber
		into #TempFirstBuySell	
		from StockData.v_StockTickSaleVsBidAsk_All as a with(nolock)
		where (ASXCode = @pvchStockCode or @pvchStockCode is null)
		and a.ObservationDate = @dtEnqDate
		--and a.Exchange = 'SMART'
		--and a.RowNumber = 1
		--order by SaleValue desc, SaleDateTime, DateFrom, DateTo;
		order by SaleDateTime desc, DateFrom desc, DateTo desc
		option(recompile);

		delete a
		from #TempFirstBuySell as a
		where RowNumber > 1;

		select 
			   ASXCode
			  ,ObservationDate
			  ,[ObservationDateTime]
			  ,[FormatBid1Volume]
			  ,case when Buy1Price = PrevBuy1Price then a.Bid1Volume - a.PrevBid1Volume 
					--when Buy1Price > PrevBuy1Price then a.Bid1Volume
					--when Buy1Price < PrevBuy1Price then -1*a.PrevBid1Volume
			   end as Bid1VolumeDelta
			  --,[Buy1NoOfOrder]
			  ,[Buy1Price]
			  ,cast([Buy1DateFrom] as time) as [Buy1DateFrom]
			  ,cast([Buy1DateTo] as time) as [Buy1DateTo]
			  ,[FormatAsk1Volume]
			  ,case when Sell1Price = PrevSell1Price then a.Ask1Volume - a.PrevAsk1Volume 
				 --when Sell1Price > PrevSell1Price then -1*a.PrevAsk1Volume
				 --when Sell1Price < PrevSell1Price then a.Ask1Volume
			   end as Ask1VolumeDelta
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
		order by ObservationDate, ASXCode, ObservationDateTime desc, Buy1DateFrom desc, Sell1DateFrom desc;

		if object_id(N'Tempdb.dbo.#TempStockPriceProfile') is not null
			drop table #TempStockPriceProfile

		select
			p.ObservationDate,
			p.ASXCode,
			ph.[Close],
			case when ph.Volume > 0 then cast(ph.[Value]/ph.Volume as decimal(20, 4)) else null end as VWAP,
			p.Price as Price,
			s1.Volume as SuppliedVolume,
			s1.TradeValue as SuppliedValue,
			s1.NumInstance as NoOfTimesSupplyAdded,
			s1.AvgAskVolume as S1AskVolume,
			s2.Volume as SuppliedVolumeConsumed,
			s2.TradeValue as SuppliedValueConsumed,
			s2.NumInstance as NoOfTimesSupplyConsumed,
			s2.AvgAskVolume as S2AskVolume,
			b1.Volume as DemandVolume,
			b1.TradeValue as DemandValue,
			b1.NumInstance as NoOfTimesDemandAdded,
			b1.AvgBidVolume as B1BidVolume,
			b2.Volume as DemandVolumeConsumed,
			b2.TradeValue as DemandValueConsumed,
			b2.NumInstance as NoOfTimesDemandConsumed,
			b2.AvgBidVolume as B2BidVolume
		into #TempStockPriceProfile
		from 
		(
			select ASXCode, ObservationDate, Buy1Price as Price
			from #TempPriceBidAsk
			union
			select ASXCode, ObservationDate, Sell1Price as Price
			from #TempPriceBidAsk
		) as p
		left join
		(
			select 
				ASXCode, ObservationDate, Sell1Price, format(sum(Ask1VolumeDelta), 'N0') as Volume, format(sum(Ask1VolumeDelta*Sell1Price), 'N0') as TradeValue, count(*) as NumInstance, format(avg(FormatAsk1Volume), 'N0') as AvgAskVolume
			from #TempPriceBidAsk
			where Ask1VolumeDelta > 0
			group by ASXCode, ObservationDate, Sell1Price
		) as s1
		on p.Price = s1.Sell1Price
		and p.ASXCode = s1.ASXCode
		and p.ObservationDate = s1.ObservationDate
		left join
		(
			select 
				ASXCode, ObservationDate, Sell1Price, format(sum(Ask1VolumeDelta), 'N0') as Volume, format(sum(Ask1VolumeDelta*Sell1Price), 'N0') as TradeValue, count(*) as NumInstance, format(avg(FormatAsk1Volume), 'N0') as AvgAskVolume
			from #TempPriceBidAsk
			where Ask1VolumeDelta < 0
			group by ASXCode, ObservationDate, Sell1Price
		) as s2
		on p.Price = s2.Sell1Price
		and p.ASXCode = s2.ASXCode
		and p.ObservationDate = s2.ObservationDate
		left join
		(
			select 
				ASXCode, ObservationDate, Buy1Price, format(sum(Bid1VolumeDelta), 'N0') as Volume, format(sum(Bid1VolumeDelta*Buy1Price), 'N0') as TradeValue, count(*) as NumInstance, format(avg(FormatBid1Volume), 'N0') as AvgBidVolume
			from #TempPriceBidAsk
			where Bid1VolumeDelta > 0
			group by ASXCode, ObservationDate, cast(ObservationDateTime as date), Buy1Price
		) as b1
		on p.Price = b1.Buy1Price
		and p.ASXCode = b1.ASXCode
		and p.ObservationDate = b1.ObservationDate
		left join
		(
			select 
				ASXCode, ObservationDate, Buy1Price, format(sum(Bid1VolumeDelta), 'N0') as Volume, format(sum(Bid1VolumeDelta*Buy1Price), 'N0') as TradeValue, count(*) as NumInstance, format(avg(FormatBid1Volume), 'N0') as AvgBidVolume
			from #TempPriceBidAsk
			where Bid1VolumeDelta < 0
			group by ASXCode, ObservationDate, cast(ObservationDateTime as date), Buy1Price
		) as b2
		on p.Price = b2.Buy1Price
		and p.ASXCode = b2.ASXCode
		and p.ObservationDate = b2.ObservationDate
		left join StockData.PriceHistory as ph
		on p.ASXCode = ph.ASXCode
		and p.ObservationDate = ph.ObservationDate
		where p.Price > 0
		order by p.ObservationDate, p.ASXCode, p.Price

		if @pbitCreateTable = 1
		begin
			if object_id(N'Working.StockPriceProfile') is not null
				drop table Working.StockPriceProfile

			select *
			into Working.StockPriceProfile
			from #TempStockPriceProfile
		end
		else
		begin
			select *
			from #TempStockPriceProfile
			order by ObservationDate, ASXCode, Price
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
