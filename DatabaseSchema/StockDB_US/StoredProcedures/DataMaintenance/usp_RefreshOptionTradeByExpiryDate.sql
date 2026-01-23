-- Stored procedure: [DataMaintenance].[usp_RefreshOptionTradeByExpiryDate]






CREATE PROCEDURE [DataMaintenance].[usp_RefreshOptionTradeByExpiryDate]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshOptionTradeByExpiryDate.sql
Stored Procedure Name: usp_RefreshOptionTradeByExpiryDate
Overview
-----------------
usp_RefreshOptionTradeByExpiryDate

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshOptionTradeByExpiryDate'
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
		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote') is not null
			drop table #TempOptionDelayedQuote

		select a.*
		into #TempOptionDelayedQuote
		from StockData.v_OptionDelayedQuote as a
		inner join 
		(
			select ASXCode, max(ObservationDate) as ObservationDate
			from StockData.v_OptionDelayedQuote
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		select 
		   a.[OptionTradeID]
		  ,a.[ASXCode]
		  ,a.[Underlying]
		  ,a.[OptionSymbol]
		  ,a.[ObservationDate]
		  ,a.[SaleTime]
		  ,a.[ExpiryDate]
		  ,a.[Expiry]
		  ,a.[Strike]
		  ,a.[PorC]
		  ,a.[Price]
		  ,a.[Size]
		  ,a.[Exchange]
		  ,a.[SpecialConditions]
		  ,a.[Multiplier]
		  ,a.[TradeValue]
		  ,a.[CreateDateTime]
		  ,a.[UpdateDateTime]
		  ,a.[BuySellIndicator]
		  --,case when (a.PorC = 'C' and a.BuySellIndicator = 'B') or (a.PorC = 'P' and a.BuySellIndicator = 'S') then 'Long'
				--when (a.PorC = 'C' and a.BuySellIndicator = 'S') or (a.PorC = 'P' and a.BuySellIndicator = 'B') then 'Short'
				--else 'Unknown'
		  -- end as [LongShortIndicator]
		  ,case when (a.PorC = 'C' and a.BuySellIndicator = 'B') then 'Long'
					when (a.PorC = 'P' and a.BuySellIndicator = 'B') then 'Short'
					else 'Unknown'
		   end as LongShortIndicator
		  ,a.[QueryBidAskAt]
		  ,a.[QueryBidNum]
		into #TempOptionTrade
		from StockData.v_OptionTrade as a
		inner join 
		(
			select ASXCode, max(ObservationDate) as ObservationDate
			from StockData.v_OptionTrade
			--where BuySellIndicator = 'B'
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
		--where a.BuySellIndicator = 'B'
		where 1 = 1
		--and cast(a.SaleTime as time) > '14:00:00'

		if object_id(N'Tempdb.dbo.#TempMoneyTypeByExpiryDate') is not null
			drop table #TempMoneyTypeByExpiryDate

		select *
		into #TempMoneyTypeByExpiryDate
		from
		(
			select
				'Dump' as MoneyType,
				ObservationDate,
				ASXCode,
				LongShortIndicator,
				ExpiryDate,
				--BuySellIndicator, 
				--x.PorC,
				sum(Size) as Size,
				sum(Size*100*Gamma) as GEX
			from
			(
				select a.*, b.Gamma
				from #TempOptionTrade as a
				inner join #TempOptionDelayedQuote as b
				on a.OptionSymbol = b.OptionSymbol
				--and a.ObservationDate = b.ObservationDate
				where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
				and a.Size < case when a.ASXCode in ('SPY.US', 'QQQ.US') then 10
								  when a.ASXCode in ('TLT.US') then 5
								  when a.ASXCode in ('SPXW.US', 'SPX.US') then 3
							 end
			) as x
			where x.ObservationDate >= dateadd(day, -50, getdate())
			group by ObservationDate, ExpiryDate, ASXCode, LongShortIndicator
			union all
			select
				'Smart' as MoneyType,
				ObservationDate,
				ASXCode,
				LongShortIndicator,
				ExpiryDate,
				--BuySellIndicator, 
				--x.PorC,
				sum(Size) as Size,
				sum(Size*100*Gamma) as GEX
			from
			(
				select a.*, b.Gamma
				from #TempOptionTrade as a
				inner join #TempOptionDelayedQuote as b
				on a.OptionSymbol = b.OptionSymbol
				--and a.ObservationDate = b.ObservationDate
				where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
				and a.Size > case when a.ASXCode in ('SPY.US', 'QQQ.US') then 50
								  when a.ASXCode in ('TLT.US') then 20
								  when a.ASXCode in ('SPXW.US', 'SPX.US') then 15
							 end
			) as x
			where x.ObservationDate >= dateadd(day, -50, getdate())
			group by ObservationDate, ExpiryDate, ASXCode, LongShortIndicator
		) as y

		if object_id(N'Tempdb.dbo.#TempResult') is not null
			drop table #TempResult

		select 
		a.ObservationDate, a.ExpiryDate, a.MoneyType, a.ASXCode, a.GEX*1.0/b.GEX as ShortLongRatio, 
		a.Size as ShortSize, b.Size as LongSize, 
		a.GEX as ShortGEX, b.GEX as LongGEX, 
		cast((a.Size - b.Size) as bigint) as ShortMinusLongSize, 
		cast((a.GEX - b.GEX) as bigint) as ShortMinusLongGEX 
		into #TempResult
		from #TempMoneyTypeByExpiryDate as a
		inner join #TempMoneyTypeByExpiryDate as b
		on a.ASXCode = b.ASXCode
		and a.MoneyType = b.MoneyType
		and a.ObservationDate = b.ObservationDate
		and a.ExpiryDate = b.ExpiryDate
		where a.LongShortIndicator = 'Short'
		and b.LongShortIndicator = 'Long'
		and a.ObservationDate >= dateadd(day, -50, getdate())
		and a.ObservationDate < a.ExpiryDate
		order by a.ObservationDate, a.ExpiryDate, a.MoneyType, a.ASXCode

		insert into [Transform].[OptionTradeByExpiryDateHistory]
		(
			[ObservationDate],
			[ExpiryDate],
			[MoneyType],
			[ASXCode],
			[ShortLongRatio],
			[ShortSize],
			[LongSize],
			[CreateDate],
			ArchiveDate,
			ShortGEX,
			LongGEX,
			ShortMinusLongSize,
			ShortMinusLongGEX
		)
		select
			a.[ObservationDate],
			a.[ExpiryDate],
			a.[MoneyType],
			a.[ASXCode],
			a.[ShortLongRatio],
			a.[ShortSize],
			a.[LongSize],
			a.[CreateDate],
			getdate() as ArchiveDate,
			a.ShortGEX,
			a.LongGEX,
			a.ShortMinusLongSize,
			a.ShortMinusLongGEX
		from [Transform].[OptionTradeByExpiryDate] as a
		inner join #TempResult as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ExpiryDate = b.ExpiryDate

		delete a
		from [Transform].[OptionTradeByExpiryDate] as a
		inner join #TempResult as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ExpiryDate = b.ExpiryDate

		insert into [Transform].[OptionTradeByExpiryDate]
		(
			[ObservationDate],
			[ExpiryDate],
			[MoneyType],
			[ASXCode],
			[ShortLongRatio],
			[ShortSize],
			[LongSize],
			CreateDate,
			ShortGEX,
			LongGEX,
			ShortMinusLongSize,
			ShortMinusLongGEX
		)
		select
			[ObservationDate],
			[ExpiryDate],
			[MoneyType],
			[ASXCode],
			[ShortLongRatio],
			[ShortSize],
			[LongSize],
			getdate() as CreateDate,
			ShortGEX,
			LongGEX,
			ShortMinusLongSize,
			ShortMinusLongGEX
		from #TempResult

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
