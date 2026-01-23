-- Stored procedure: [StockData].[usp_DeriveSignificantOptionTrade]


CREATE PROCEDURE [StockData].[usp_DeriveSignificantOptionTrade]
@pbitDebug AS BIT = 0,
@pvchUnderlying varchar(10),
@pdtStartDateTime smalldatetime,
@pdtEndDateTime smalldatetime,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_DeriveSignificantOptionTrade.sql
Stored Procedure Name: usp_DeriveSignificantOptionTrade
Overview
-----------------
usp_DeriveSignificantOptionTrade

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
Date:		2022-07-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_DeriveSignificantOptionTrade'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pdtStartDateTime as smalldatetime = '2022-07-10 11:28:53.067'
		--declare @pdtEndDateTime as smalldatetime = '2022-07-22 11:28:53.067'
		--declare @pvchUnderlying as varchar(10) = 'SPY'
		declare @pdtStartDateTimeUTC as smalldatetime
		select @pdtStartDateTimeUTC = (@pdtStartDateTime at time zone 'AUS Eastern Standard Time') AT TIME ZONE 'UTC'
		declare @pdtEndDateTimeUTC as smalldatetime
		select @pdtEndDateTimeUTC = (@pdtEndDateTime at time zone 'AUS Eastern Standard Time') AT TIME ZONE 'UTC'

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		select 
			Price*Size*isnull(Multiplier, 100) as TradeValue, 
			cast(CONVERT(datetime, SWITCHOFFSET(SaleTime, DATEPART(TZOFFSET, SaleTime AT TIME ZONE 'AUS Eastern Standard Time'))) as date) as ObservationDate,
			a.*
		into #TempOptionTrade
		from StockData.OptionTrade as a
		left join StockData.OptionContract as b
		on a.OptionSymbol = b.OptionSymbol
		where a.Underlying = @pvchUnderlying
		and SaleTime between @pdtStartDateTimeUTC and @pdtEndDateTimeUTC
		order by a.Underlying desc

		if object_id(N'Tempdb.dbo.#TempOptionTrade2') is not null
			drop table #TempOptionTrade2
		
		select 
			a.*,
			isnull(z.AvgSize*10, 100) as SignificantSize,
			ntile(200) over (partition by a.Underlying, a.ObservationDate order by TradeValue desc) as NtileRank
		into #TempOptionTrade2
		from #TempOptionTrade as a
		left join
		(
			select ASXCode, avg(size) as AvgSize 
			from StockData.OptionTrade
			group by ASXCode
		) as z
		on a.ASXCode = z.ASXCode

		insert into [StockData].[SignificantOptionTrade]
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[SaleTime]
		  ,[Price]
		  ,[Size]
		  ,[Exchange]
		  ,[SpecialConditions]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		  ,[BuySellIndicator]
		  ,[LongShortIndicator]
		)
		select 
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[SaleTime]
		  ,[Price]
		  ,[Size]
		  ,[Exchange]
		  ,[SpecialConditions]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		  ,null as [BuySellIndicator]
		  ,null as [LongShortIndicator]		
		from #TempOptionTrade as a

		--insert into [StockData].[SignificantOptionTrade]
		--(
		--   [ASXCode]
		--  ,[Underlying]
		--  ,[OptionSymbol]
		--  ,[SaleTime]
		--  ,[Price]
		--  ,[Size]
		--  ,[Exchange]
		--  ,[SpecialConditions]
		--  ,[CreateDateTime]
		--  ,[UpdateDateTime]
		--  ,[BuySellIndicator]
		--  ,[LongShortIndicator]
		--)
		--select 
		--   [ASXCode]
		--  ,[Underlying]
		--  ,[OptionSymbol]
		--  ,[SaleTime]
		--  ,[Price]
		--  ,[Size]
		--  ,[Exchange]
		--  ,[SpecialConditions]
		--  ,[CreateDateTime]
		--  ,[UpdateDateTime]
		--  ,null as [BuySellIndicator]
		--  ,null as [LongShortIndicator]		
		--from #TempOptionTrade2 as a
		--where NtileRank = 1
		----and Size > SignificantSize
		--and TradeValue > 10000
		--and not exists
		--(
		--	select 1
		--	from [StockData].[SignificantOptionTrade]
		--	where ASXCode = a.ASXCode
		--	and OptionSymbol = a.OptionSymbol
		--	and SaleTime = a.SaleTime
		--	and Price = a.Price
		--	and Size = a.Size
		--)
		--order by TradeValue desc;

		--select *
		--from #TempOptionTrade2
		--where NtileRank = 1
		--and Size > SignificantSize
		--and TradeValue > 50000
		
		--select ASXCode, cast(SaleTime as date), count(*) from StockData.OptionTrade
		--group by ASXCode, cast(SaleTime as date)


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
