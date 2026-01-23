-- Stored procedure: [Transform].[usp_RefreshBrokerProfitLossRank]



CREATE PROCEDURE [Transform].[usp_RefreshBrokerProfitLossRank]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintBatchSize as int = 200
AS
/******************************************************************************
File: usp_RefreshBrokerProfitLossRank.sql
Stored Procedure Name: usp_RefreshBrokerProfitLossRank
Overview
-----------------
usp_RefreshBrokerProfitLossRank

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
Date:		2023-08-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBrokerProfitLossRank'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Transform'
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
		
		if object_id(N'Tempdb.dbo.#TempBRByStock') is not null
			drop table #TempBRByStock

		select a.*, c.[Close], c.Next10DaysChange, c.Next2DaysChange, c.Next5DaysChange, c.TomorrowChange
		into #TempBRByStock
		from StockData.BrokerReport as a
		--inner join Transform.MostTradedSmallCap as b
		--on a.ASXCode = b.ASXCode
		inner join StockData.v_PriceHistory as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		where 1 = 1 --a.ASXCode = @vchASXCode
		and a.ObservationDate >= dateadd(day, -30*12, getdate())

		if object_id(N'Transform.BrokerProfitLossRank') is not null
			drop table Transform.BrokerProfitLossRank

		select 
		x.ASXCode,
		x.BrokerCode, format(x.TrueVolume, 'N0') as TrueVolume, y.SellPerShare, y.BuyPerShare, 
		format(y.ProfiltPerShare, 'N6') as ProfiltPerShare, 
		format(ProfiltPerShare*TrueVolume, 'N0') as MarketProfit,
		format((LatestClose-BuyPerShare)*RemainVolume, 'N0') as HoldingStockProfit,
		format(ProfiltPerShare*TrueVolume + (LatestClose-BuyPerShare)*RemainVolume, 'N0') as TotalProfit,
		format(RemainVolume, 'N0') as RemainVolume,
		row_number() over (partition by x.ASXCode order by ProfiltPerShare*TrueVolume + (LatestClose-BuyPerShare)*RemainVolume desc) as ProfitRank,
		row_number() over (partition by x.ASXCode order by ProfiltPerShare*TrueVolume + (LatestClose-BuyPerShare)*RemainVolume asc) as LossRank,
		(select max(ObservationDate) from StockData.BrokerReport) as ObservationDate
		into Transform.BrokerProfitLossRank
		from
		(
			select ASXCode, BrokerCode, case when sum(BuyVolume) > sum(SellVolume) then sum(SellVolume) else sum(BuyVolume) end as TrueVolume, case when sum(BuyVolume) > sum(SellVolume) then sum(BuyVolume) - sum(SellVolume) else 0 end as RemainVolume
			from #TempBRByStock
			where 1 = 1
			group by ASXCode, BrokerCode
			having sum(SellVolume) > 0
			and sum(BuyVolume) > 0
		) as x
		inner join
		(
			select ASXCode, BrokerCode, sum(SellValue)*1.0/sum(SellVolume) as SellPerShare, sum(BuyValue)*1.0/sum(BuyVolume) as BuyPerShare, case when sum(SellVolume)=0 or sum(BuyVolume)=0 then null else sum(SellValue)*1.0/sum(SellVolume) - sum(BuyValue)*1.0/sum(BuyVolume) end as ProfiltPerShare
			from #TempBRByStock
			where 1 = 1
			group by ASXCode, BrokerCode
			having sum(SellVolume) > 0
			and sum(BuyVolume) > 0
		) as y
		on x.BrokerCode = y.BrokerCode
		and x.ASXCode = y.ASXCode
		inner join
		(
			select ASXCode, [Close] as LatestClose, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from #TempBRByStock
		) as z
		on z.RowNumber = 1
		and x.ASXCode = Z.ASXCode
		order by x.ASXCode, ProfiltPerShare*TrueVolume + (LatestClose-BuyPerShare)*RemainVolume desc;

		
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
