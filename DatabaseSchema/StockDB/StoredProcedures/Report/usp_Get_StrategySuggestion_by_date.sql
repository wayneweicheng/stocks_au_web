-- Stored procedure: [Report].[usp_Get_StrategySuggestion_by_date]


CREATE PROCEDURE [Report].[usp_Get_StrategySuggestion_by_date]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSelectItem as varchar(500),
@pdtObservationDate as date
AS
/******************************************************************************
File: usp_Get_StrategySuggestion.sql
Stored Procedure Name: usp_Get_StrategySuggestion
Overview
-----------------
usp_Get_StrategySuggestion

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
Date:		2018-08-20
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_StrategySuggestion'
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
		declare @pintNumPrevDay as int
		SELECT @pintNumPrevDay = -1*Common.BusinessDayDiff(@pdtObservationDate, CAST(GETDATE() AS DATE))

		-- If you need to ensure the sign is correct (since we're going backward)
		IF @pintNumPrevDay > 0
			SET @pintNumPrevDay = @pintNumPrevDay * -1
		ELSE
			SET @pintNumPrevDay = ABS(@pintNumPrevDay)

		--SELECT @pintNumPrevDay AS NumPrevDays

		if @pvchSelectItem = 'High Buy vs Sell'
		begin
			exec [Report].[usp_Get_Strategy_HighBuyvsSell]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Today Close Cross Over VWAP'
		begin
			exec [Report].[usp_Get_Strategy_TodayCloseCrossOverVWAP]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Overcome Big Sell'
		begin
			exec [Report].usp_Get_Strategy_OvercomeBigSell
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Tree Shake Morning Market'
		begin
			exec [Report].usp_Get_Strategy_TreeShakeMorningMarket
			@pintNumPrevDay = @pintNumPrevDay
		end

		if @pvchSelectItem = 'Break Out Retrace'
		begin
			exec [Report].usp_Get_Strategy_BreakoutRetrace
			@pintNumPrevDay = @pintNumPrevDay
		end

		if @pvchSelectItem = 'Broker Buy Retail Sell'
		begin
			exec [Report].usp_Get_Strategy_BrokerBuyRetailSell
			@pintNumPrevDay = @pintNumPrevDay
		end

		if @pvchSelectItem = 'Broker Buy Retail Sell - 3 Days'
		begin
			exec [Report].usp_Get_Strategy_BrokerBuyRetailSell
			@pintNumPrevDay = @pintNumPrevDay,
			@pintNoOfDays = 3
		end

		if @pvchSelectItem = 'Broker Buy Retail Sell - 5 Days'
		begin
			exec [Report].usp_Get_Strategy_BrokerBuyRetailSell
			@pintNumPrevDay = @pintNumPrevDay,
			@pintNoOfDays = 5
		end

		if @pvchSelectItem = 'Broker Buy Retail Sell - 10 Days'
		begin
			exec [Report].usp_Get_Strategy_BrokerBuyRetailSell
			@pintNumPrevDay = @pintNumPrevDay,
			@pintNoOfDays = 10
		end

		if @pvchSelectItem = 'Heavy Retail Sell'
		begin
			exec [Report].usp_Get_Strategy_HeavyRetailSell
			@pintNumPrevDay = @pintNumPrevDay
		end

		if @pvchSelectItem = 'Heavy Retail Sell - 3 Days'
		begin
			exec [Report].usp_Get_Strategy_HeavyRetailSell
			@pintNumPrevDay = @pintNumPrevDay,
			@pintNoOfDays = 3
		end

		if @pvchSelectItem = 'Heavy Retail Sell - 5 Days'
		begin
			exec [Report].usp_Get_Strategy_HeavyRetailSell
			@pintNumPrevDay = @pintNumPrevDay,
			@pintNoOfDays = 5
		end

		if @pvchSelectItem = 'Broker Buy Price (recent 1, 3, 5, 10 days)'
		begin
			exec [Report].[usp_Get_Strategy_TopBrokerBuyPrice]
			@pintNumPrevDay = @pintNumPrevDay
		end

		if @pvchSelectItem = 'Broker New Buy Report (Today only)'
		begin
			exec [Report].[usp_Get_Strategy_BrokerNewBuy]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Director Subscribe SPP'
		begin
			exec [Report].[usp_Get_Strategy_DirectorSubscribeSPP]
		end
		
		if @pvchSelectItem = 'Gold Interception'
		begin
			exec [Report].[usp_Get_Strategy_GoldInterception]
		end
		
		if @pvchSelectItem = 'Top 20 Holder Stocks'
		begin
			exec [Report].[usp_Get_Strategy_Top20HolderStocks]

		end 

		if @pvchSelectItem = 'Price Swing Stocks'
		begin
			exec [Report].[usp_Get_Strategy_PriceSwingStocks]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Break Through Previous Break Through High'
		begin
			exec [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]
			@pintNumPrevDay = @pintNumPrevDay
		end 
		
		if @pvchSelectItem = 'Long Bullish Bar'
		begin
			exec [Report].[usp_Get_Strategy_LongBullishBar]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Retreat To Weekly MA10'
		begin
			exec [Report].[usp_Get_Strategy_RetreatToWeeklyMA10]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Volume Volatility Contraction'
		begin
			exec [Report].usp_Get_Strategy_VolumeVolatilityContraction
			@pintNumPrevDay = @pintNumPrevDay
		end 
		
		if @pvchSelectItem = 'High Probability Pair Broker Setup'
		begin
			exec [Report].[usp_Get_Strategy_HighWinPairBrokerSetup]
			@pintNumPrevDay = @pintNumPrevDay
		end 
		
		if @pvchSelectItem = 'Monitor Stocks Price Retrace'
		begin
			exec [Report].[usp_Get_Strategy_monitorstockpriceretrace]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Get Today Filter Overlaps (Today Only)'
		begin
			exec [Report].[usp_Get_Strategy_GetTodayFilterOverlaps]
			@pintNumPrevDay = 0
		end 

		if @pvchSelectItem = 'Price Break Through Placement Price'
		begin
			exec [Report].[usp_Get_Strategy_PriceBreakThroughPlacementPrice]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Trace Momentum Stock (Today Only)'
		begin
			exec [Report].[usp_Get_Strategy_TraceMomentumStock]
			@pintNumPrevDay = 0
		end 		
		
		if @pvchSelectItem = 'Advanced FRCS'
		begin
			exec [Report].[usp_Get_Strategy_AdvancedFRCS]
			@pintNumPrevDay = @pintNumPrevDay
		end 
		
		if @pvchSelectItem = 'New High Minor Retrace'
		begin
			exec [Report].[usp_Get_Strategy_NewHighMinorRetrace]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Advanced HBXF'
		begin
			exec [Report].[usp_Get_Strategy_AdvancedHBXF]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Most Recent Tweet'
		begin
			exec [Report].[usp_Get_Strategy_MostRecentTweet]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'ChiX Analysis'
		begin
			--exec [Report].[usp_Get_Strategy_ChiXAnalysis]
			--@pintNumPrevDay = 0

			exec [Report].[usp_Get_Strategy_ChiXVolumeSurge]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Final Institute Dump'
		begin
			exec [Report].[usp_Get_Strategy_FinalInstituteDump]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Institute Performance High Buy'
		begin
			exec [Report].[usp_Get_Strategy_DerivedInstitutePerformance_HighBuy]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Institute Performance High Participation'
		begin
			exec [Report].[usp_Get_Strategy_DerivedInstitutePerformance_HighParticipation]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Bullish Bar Cross MA'
		begin
			exec [Report].[usp_Get_Strategy_BullishBarCorssMA]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Low Market Cap'
		begin
			exec [Report].[usp_Get_Strategy_LowMarketCap]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Announcement Search Result'
		begin
			exec [Report].[usp_Get_Strategy_AnnouncementSearchResult]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Breakaway Gap'
		begin
			exec [Report].[usp_Get_Strategy_BreakawayGap]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Sign of bull run'
		begin
			exec [Report].[usp_Get_Strategy_SignOfBullRun]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Tip System'
		begin
			exec [Report].[usp_Get_Strategy_TipSystem]
			@pintNumPrevDay = 0
		end 

		if @pvchSelectItem = 'Break Last 3d VWAP'
		begin
			exec [Report].[usp_Get_Strategy_BreakLast3DVWAP]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Today Market Scan'
		begin
			exec [Report].[usp_Get_Strategy_TodayMarketScan]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		if @pvchSelectItem = 'Stock Strong Buys'
		begin
			exec [StockData].[usp_GetFirstBuySell_Buy]
			@pintNumPrevDay = @pintNumPrevDay
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