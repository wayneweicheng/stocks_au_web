-- Stored procedure: [StockData].[usp_UpdateStockAttribute]





CREATE PROCEDURE [StockData].[usp_UpdateStockAttribute]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockAttribute varchar(max)
AS
/******************************************************************************
File: usp_UpdateStockAttribute.sql
Stored Procedure Name: usp_UpdateStockAttribute
Overview
-----------------
usp_UpdateStockAttribute

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
Date:		2019-05-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateStockAttribute'
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
		declare @vchStockCode as varchar(10)
		declare @xmlStockAttribute as xml
		--select @xmlMarketDepth = cast(RawData as xml) from StockData.RawData
		--where RawDataID = 9

--		declare @pvchStockAttributeTest as varchar(max) = '
--<Stock xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
--  <stockCode>14D.AX</stockCode>
--  <observationDate>2019-05-22T00:00:00</observationDate>
--  <peakPrice>0</peakPrice>
--  <troughPrice>0</troughPrice>
--  <last60dMaxPeak>0</last60dMaxPeak>
--  <prev1Peak>0</prev1Peak>
--  <prev2Peak>0</prev2Peak>
--  <last60dMinTrough>0</last60dMinTrough>
--  <prev1Trough>0</prev1Trough>
--  <prev2Trough>0</prev2Trough>
--  <close>0.285</close>
--  <open>0.29</open>
--  <high>0.29</high>
--  <low>0.285</low>
--  <maxOpenClose>0.29</maxOpenClose>
--  <minOpenClose>0.285</minOpenClose>
--  <spread>-0.017241379310344845</spread>
--  <gainLossPecentage>-1.7241379310344844</gainLossPecentage>
--  <volume>54827</volume>
--  <movingAverage5d>0.2889999999999997</movingAverage5d>
--  <movingAverage10d>0.29149999999999987</movingAverage10d>
--  <movingAverage15d>0.29266666666666691</movingAverage15d>
--  <movingAverage20d>0.29700000000000004</movingAverage20d>
--  <movingAverage30d>0.29983333333333334</movingAverage30d>
--  <movingAverage60d>0.31091666666666651</movingAverage60d>
--  <movingAverage120d>0.30887499999999979</movingAverage120d>
--  <movingAverage135d>0.30570370370370353</movingAverage135d>
--  <movingAverage200d>0.30940119760479018</movingAverage200d>
--  <movingAverage5dVol>83610.4</movingAverage5dVol>
--  <movingAverage10dVol>116655.2</movingAverage10dVol>
--  <movingAverage15dVol>119304.33333333333</movingAverage15dVol>
--  <movingAverage20dVol>137028.85</movingAverage20dVol>
--  <movingAverage30dVol>135740.36666666667</movingAverage30dVol>
--  <movingAverage60dVol>122762.73333333334</movingAverage60dVol>
--  <movingAverage120dVol>135499.05925925926</movingAverage120dVol>
--  <expMovingAverage7d>0.28988467444019067</expMovingAverage7d>
--  <expMovingAverage15d>0.29356156720121207</expMovingAverage15d>
--  <expMovingAverage30d>0.29919365097713096</expMovingAverage30d>
--  <expMovingAverage50d>0.30469146361459853</expMovingAverage50d>
--  <maxClose5d>0.3</maxClose5d>
--  <maxClose10d>0.305</maxClose10d>
--  <maxClose15d>0.305</maxClose15d>
--  <maxClose20d>0.32</maxClose20d>
--  <minClose5d>0.285</minClose5d>
--  <minClose10d>0.285</minClose10d>
--  <minClose15d>0.285</minClose15d>
--  <minClose20d>0.285</minClose20d>
--  <priceSpread5d>0.052631578947368474</priceSpread5d>
--  <priceSpread10d>0.0701754385964913</priceSpread10d>
--  <priceSpread15d>0.0701754385964913</priceSpread15d>
--  <priceSpread20d>0.12280701754385977</priceSpread20d>
--  <upperShadowVsBodyRatio>0</upperShadowVsBodyRatio>
--  <bottomShadowVsBodyRatio>0</bottomShadowVsBodyRatio>
--  <macdMACD>-0.0054900874351795914</macdMACD>
--  <macdSignal>-0.0050413606411941949</macdSignal>
--  <macdHist>-0.00044872679398539651</macdHist>
--  <RSI>43.478260869565219</RSI>
--</Stock>'

		select @xmlStockAttribute = cast(@pvchStockAttribute as xml)

		select @vchStockCode = @xmlStockAttribute.value('(/Stock/stockCode)[1]', 'varchar(20)')

		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		select
			40 as DataTypeID,
			@pvchStockAttribute as RawData,
			getdate() as CreateDate,
			null as SourceSystemDate

		if object_id(N'Tempdb.dbo.#TempStockAttribute') is not null
			drop table #TempStockAttribute

		select 
			x.si.value('stockCode[1]', 'varchar(100)') as [ASXCode],
			x.si.value('observationDate[1]', 'varchar(100)') as observationDate,
			x.si.value('close[1]', 'varchar(100)') as [close],
			x.si.value('open[1]', 'varchar(100)') as [open],
			x.si.value('high[1]', 'varchar(100)') as [high],
			x.si.value('low[1]', 'varchar(100)') as [low],
			x.si.value('maxOpenClose[1]', 'varchar(100)') as [maxOpenClose],
			x.si.value('minOpenClose[1]', 'varchar(100)') as [minOpenClose],
			x.si.value('spread[1]', 'varchar(100)') as [spread],
			x.si.value('gainLossPecentage[1]', 'varchar(100)') as [gainLossPecentage],
			x.si.value('volume[1]', 'varchar(100)') as [volume],
			x.si.value('movingAverage5d[1]', 'varchar(100)') as [movingAverage5d],
			x.si.value('movingAverage10d[1]', 'varchar(100)') as [movingAverage10d],
			x.si.value('movingAverage15d[1]', 'varchar(100)') as [movingAverage15d],
			x.si.value('movingAverage20d[1]', 'varchar(100)') as [movingAverage20d],
			x.si.value('movingAverage30d[1]', 'varchar(100)') as [movingAverage30d],
			x.si.value('movingAverage60d[1]', 'varchar(100)') as [movingAverage60d],
			x.si.value('movingAverage120d[1]', 'varchar(100)') as [movingAverage120d],
			x.si.value('movingAverage135d[1]', 'varchar(100)') as [movingAverage135d],
			x.si.value('movingAverage200d[1]', 'varchar(100)') as [movingAverage200d],

			x.si.value('movingAverage5dVol[1]', 'varchar(100)') as [movingAverage5dVol],
			x.si.value('movingAverage10dVol[1]', 'varchar(100)') as [movingAverage10dVol],
			x.si.value('movingAverage15dVol[1]', 'varchar(100)') as [movingAverage15dVol],
			x.si.value('movingAverage20dVol[1]', 'varchar(100)') as [movingAverage20dVol],
			x.si.value('movingAverage30dVol[1]', 'varchar(100)') as [movingAverage30dVol],
			x.si.value('movingAverage60dVol[1]', 'varchar(100)') as [movingAverage60dVol],
			x.si.value('movingAverage120dVol[1]', 'varchar(100)') as movingAverage120dVol,

			x.si.value('expMovingAverage7d[1]', 'varchar(100)') as [expMovingAverage7d],
			x.si.value('expMovingAverage15d[1]', 'varchar(100)') as [expMovingAverage15d],
			x.si.value('expMovingAverage30d[1]', 'varchar(100)') as [expMovingAverage30d],
			x.si.value('expMovingAverage50d[1]', 'varchar(100)') as [expMovingAverage50d],

			x.si.value('maxClose5d[1]', 'varchar(100)') as [maxClose5d],
			x.si.value('maxClose10d[1]', 'varchar(100)') as [maxClose10d],
			x.si.value('maxClose15d[1]', 'varchar(100)') as [maxClose15d],
			x.si.value('maxClose20d[1]', 'varchar(100)') as [maxClose20d],

			x.si.value('minClose5d[1]', 'varchar(100)') as [minClose5d],
			x.si.value('minClose10d[1]', 'varchar(100)') as [minClose10d],
			x.si.value('minClose15d[1]', 'varchar(100)') as [minClose15d],
			x.si.value('minClose20d[1]', 'varchar(100)') as [minClose20d],

			x.si.value('priceSpread5d[1]', 'varchar(100)') as [priceSpread5d],
			x.si.value('priceSpread10d[1]', 'varchar(100)') as [priceSpread10d],
			x.si.value('priceSpread15d[1]', 'varchar(100)') as [priceSpread15d],
			x.si.value('priceSpread20d[1]', 'varchar(100)') as [priceSpread20d],

			x.si.value('upperShadowVsBodyRatio[1]', 'varchar(100)') as [upperShadowVsBodyRatio],
			x.si.value('bottomShadowVsBodyRatio[1]', 'varchar(100)') as [bottomShadowVsBodyRatio],
			x.si.value('macdMACD[1]', 'varchar(100)') as [macdMACD],
			x.si.value('macdSignal[1]', 'varchar(100)') as [macdSignal],
			x.si.value('macdHist[1]', 'varchar(100)') as [macdHist],
			x.si.value('RSI[1]', 'varchar(100)') as [RSI],
			x.si.value('CLHL[1]', 'varchar(100)') as [CLHL],

			x.si.value('BullEngulfing[1]', 'varchar(100)') as [BullEngulfing],
			x.si.value('Doji[1]', 'varchar(100)') as [Doji],
			x.si.value('DragonflyDoji[1]', 'varchar(100)') as [DragonflyDoji],
			x.si.value('EveningStar[1]', 'varchar(100)') as [EveningStar],
			x.si.value('GravestoneDoji[1]', 'varchar(100)') as [GravestoneDoji],
			x.si.value('Hammer[1]', 'varchar(100)') as [Hammer],
			x.si.value('HangingMan[1]', 'varchar(100)') as [HangingMan],
			x.si.value('HaramiPattern[1]', 'varchar(100)') as [HaramiPattern],
			x.si.value('InvertedHammer[1]', 'varchar(100)') as [InvertedHammer],
			x.si.value('LongLeggedDoji[1]', 'varchar(100)') as [LongLeggedDoji],
			x.si.value('MorningStar[1]', 'varchar(100)') as [MorningStar],
			x.si.value('PullBackReverse[1]', 'varchar(100)') as [PullBackReverse]
		into #TempStockAttribute
		from @xmlStockAttribute.nodes('/Stock') as x(si)

		delete a
		from [StockData].[StockAttribute] as a
		inner join #TempStockAttribute as b
		on a.ObservationDate = try_cast(left(b.[ObservationDate], 10) as date)
		and a.ASXCode = b.ASXCode

		insert into [StockData].[StockAttribute]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[CreateDate]
		  ,[MovingAverage5d]
		  ,[MovingAverage10d]
		  ,[MovingAverage15d]
		  ,[MovingAverage20d]
		  ,[MovingAverage30d]
		  ,[MovingAverage60d]
		  ,[MovingAverage120d]
		  ,[MovingAverage135d]
		  ,[MovingAverage200d]
		  ,[MovingAverage5dVol]
		  ,[MovingAverage10dVol]
		  ,[MovingAverage15dVol]
		  ,[MovingAverage20dVol]
		  ,[MovingAverage30dVol]
		  ,[MovingAverage60dVol]
		  ,[MovingAverage120dVol]
		  ,[ExpMovingAverage7d]
		  ,[ExpMovingAverage15d]
		  ,[ExpMovingAverage30d]
		  ,[ExpMovingAverage50d]
		  ,[MaxClose5d]
		  ,[MaxClose10d]
		  ,[MaxClose15d]
		  ,[MaxClose20d]
		  ,[MinClose5d]
		  ,[MinClose10d]
		  ,[MinClose15d]
		  ,[MinClose20d]
		  ,[PriceSpread5d]
		  ,[PriceSpread10d]
		  ,[PriceSpread15d]
		  ,[PriceSpread20d]
		  ,[UpperShadowVsBodyRatio]
		  ,[BottomShadowVsBodyRatio]
		  ,[MACDMACD]
		  ,[MACDSignal]
		  ,[MACDHist]
		  ,[RSI]
		  ,[Support1]
		  ,[Support2]
		  ,[Support3]
		  ,[Resistence1]
		  ,[Resistence2]
		  ,[Resistence3]
		  ,[CLHL]
		  ,[BullEngulfing]
		  ,[Doji]
		  ,[DragonflyDoji]
		  ,[EveningStar]
		  ,[GravestoneDoji]
		  ,[Hammer]
		  ,[HangingMan]
		  ,[HaramiPattern]
		  ,[InvertedHammer]
		  ,[LongLeggedDoji]
		  ,[MorningStar]
		  ,PullBackReverse
		)
		select
		   [ASXCode]
		  ,try_cast(left([ObservationDate], 10) as date)
		  ,try_cast([Close] as decimal(20, 4))
		  ,try_cast([Open] as decimal(20, 4))
		  ,try_cast([Low] as decimal(20, 4))
		  ,try_cast([High] as decimal(20, 4))
		  ,try_cast([Volume] as bigint)
		  ,getdate() as [CreateDate]
		  ,try_cast([MovingAverage5d] as decimal(20, 4))
		  ,try_cast([MovingAverage10d] as decimal(20, 4))
		  ,try_cast([MovingAverage15d] as decimal(20, 4))
		  ,try_cast([MovingAverage20d] as decimal(20, 4))
		  ,try_cast([MovingAverage30d] as decimal(20, 4))
		  ,try_cast([MovingAverage60d] as decimal(20, 4))
		  ,try_cast([MovingAverage120d] as decimal(20, 4))
		  ,try_cast([MovingAverage135d] as decimal(20, 4))
		  ,try_cast([MovingAverage200d] as decimal(20, 4))
		  ,try_cast([MovingAverage5dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage10dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage15dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage20dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage30dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage60dVol] as decimal(20, 4))
		  ,try_cast([MovingAverage120dVol] as decimal(20, 4))
		  ,try_cast([ExpMovingAverage7d] as decimal(20, 4))
		  ,try_cast([ExpMovingAverage15d] as decimal(20, 4))
		  ,try_cast([ExpMovingAverage30d] as decimal(20, 4))
		  ,try_cast([ExpMovingAverage50d] as decimal(20, 4))
		  ,try_cast([MaxClose5d] as decimal(20, 4))
		  ,try_cast([MaxClose10d] as decimal(20, 4))
		  ,try_cast([MaxClose15d] as decimal(20, 4))
		  ,try_cast([MaxClose20d] as decimal(20, 4))
		  ,try_cast([MinClose5d] as decimal(20, 4))
		  ,try_cast([MinClose10d] as decimal(20, 4))
		  ,try_cast([MinClose15d] as decimal(20, 4))
		  ,try_cast([MinClose20d] as decimal(20, 4))
		  ,try_cast([PriceSpread5d] as decimal(20, 4))
		  ,try_cast([PriceSpread10d] as decimal(20, 4))
		  ,try_cast([PriceSpread15d] as decimal(20, 4))
		  ,try_cast([PriceSpread20d] as decimal(20, 4))
		  ,try_cast([UpperShadowVsBodyRatio] as decimal(20, 4))
		  ,try_cast([BottomShadowVsBodyRatio] as decimal(20, 4))
		  ,try_cast([MACDMACD] as decimal(20, 4))
		  ,try_cast([MACDSignal] as decimal(20, 4))
		  ,try_cast([MACDHist] as decimal(20, 4))
		  ,try_cast([RSI] as decimal(20, 4))
		  ,null as [Support1]
		  ,null as [Support2]
		  ,null as [Support3]
		  ,null as [Resistence1]
		  ,null as [Resistence2]
		  ,null as [Resistence3]
		  ,null as [CLHL]
		  ,null as [BullEngulfing]
		  ,null as [Doji]
		  ,null as [DragonflyDoji]
		  ,null as [EveningStar]
		  ,null as [GravestoneDoji]
		  ,null as [Hammer]
		  ,null as [HangingMan]
		  ,null as [HaramiPattern]
		  ,null as [InvertedHammer]
		  ,null as [LongLeggedDoji]
		  ,MorningStar as [MorningStar]
		  ,PullBackReverse as PullBackReverse
		from #TempStockAttribute

		
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
