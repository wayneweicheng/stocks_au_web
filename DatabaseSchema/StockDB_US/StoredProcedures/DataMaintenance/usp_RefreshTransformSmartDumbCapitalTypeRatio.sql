-- Stored procedure: [DataMaintenance].[usp_RefreshTransformSmartDumbCapitalTypeRatio]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformSmartDumbCapitalTypeRatio]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformSmartDumbCapitalTypeRatio.sql
Stored Procedure Name: usp_RefreshTransformSmartDumbCapitalTypeRatio
Overview
-----------------
usp_RefreshTransformSmartDumbCapitalTypeRatio

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
Date:		2021-09-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformSmartDumbCapitalTypeRatio'
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

		if object_id(N'Tempdb.dbo.#TempMoneyTypeByExpiryDate') is not null
			drop table #TempMoneyTypeByExpiryDate

		select *
		into #TempMoneyTypeByExpiryDate
		from
		(
			select
				'Dumb' as MoneyType,
				ObservationDate,
				ASXCode,
				BuySellIndicator,
				PorC,
				ExpiryDate,
				--BuySellIndicator, 
				--x.PorC,
				sum(Size) as Size,
				sum(Size*100*Gamma) as GEX
			from
			(
				select a.*, isnull(b.Gamma, c.Gamma) as Gamma
				from StockData.v_OptionTrade as a with(nolock)
				left join StockData.v_OptionDelayedQuote as b with(nolock)
				on a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate = b.ObservationDate
				left join #TempOptionDelayedQuote as c with(nolock)
				on a.OptionSymbol = c.OptionSymbol
				where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
				--and a.TradeValue < 10000
				and a.Size < case when a.ASXCode in ('SPY.US', 'QQQ.US') then 10
								  when a.ASXCode in ('TLT.US') then 5
								  when a.ASXCode in ('SPXW.US', 'SPX.US') then 3
							 end
			) as x
			where x.ObservationDate >= dateadd(day, -10, getdate())
			group by ObservationDate, ExpiryDate, ASXCode, BuySellIndicator, PorC
			union all
			select
				'Smart' as MoneyType,
				ObservationDate,
				ASXCode,
				BuySellIndicator, 
				PorC,
				ExpiryDate,
				--BuySellIndicator, 
				--x.PorC,
				sum(Size) as Size,
				sum(Size*100*Gamma) as GEX
			from
			(
				select a.*, isnull(b.Gamma, c.Gamma) as Gamma
				from StockData.v_OptionTrade as a with(nolock)
				left join StockData.v_OptionDelayedQuote as b with(nolock)
				on a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate = b.ObservationDate
				left join #TempOptionDelayedQuote as c with(nolock)
				on a.OptionSymbol = c.OptionSymbol
				where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
				--and a.TradeValue > 50000
				and a.Size > case when a.ASXCode in ('SPY.US', 'QQQ.US') then 50
								  when a.ASXCode in ('TLT.US') then 20
								  when a.ASXCode in ('SPXW.US', 'SPX.US') then 15
							 end
			) as x
			where x.ObservationDate >= dateadd(day, -10, getdate())
			group by ObservationDate, ExpiryDate, ASXCode, BuySellIndicator, PorC
		) as y

		if object_id(N'Tempdb.dbo.#TempSmartDumbCapitalTypeRatio') is not null
			drop table #TempSmartDumbCapitalTypeRatio

		select
		x.ASXCode,
		x.ObservationDate, x.CapitalType, 
		x.GEX as DumbGEX, x.AggPerc as DumbAggPerc, 
		y.GEX as SmartGEX, y.AggPerc as SmartAggPerc, 
		y.AggPerc*1.0/x.AggPerc as SmartDumbAggPercRatio
		into #TempSmartDumbCapitalTypeRatio
		from
		(
			select 
				ASXCode,
				ObservationDate,
				MoneyType, 
				case when BuySellIndicator = 'B' and PorC = 'C' then 'a. Long In'
					 when BuySellIndicator = 'S' and PorC = 'P' then 'b. Short out'
					 when BuySellIndicator = 'B' and PorC = 'P' then 'c. Short In'
					 when BuySellIndicator = 'S' and PorC = 'C' then 'd. Long out'
				end as CapitalType, sum(Size) as Size, sum(GEX) as GEX,
				cast(sum(GEX)*100.0/sum(sum(GEX)) over (partition by ASXCode, MoneyType, ObservationDate) as decimal(10, 2)) as AggPerc
			from #TempMoneyTypeByExpiryDate
			where ObservationDate >= dateadd(day, -10, getdate())
			and MoneyType = 'Dumb'
			and BuySellIndicator in ('B', 'S')
			group by ASXCode, MoneyType, ObservationDate, BuySellIndicator, PorC
		) as x
		inner join
		(
			select 
				ASXCode, 
				ObservationDate,
				MoneyType, 
				case when BuySellIndicator = 'B' and PorC = 'C' then 'a. Long In'
					 when BuySellIndicator = 'S' and PorC = 'P' then 'b. Short out'
					 when BuySellIndicator = 'B' and PorC = 'P' then 'c. Short In'
					 when BuySellIndicator = 'S' and PorC = 'C' then 'd. Long out'
				end as CapitalType, sum(Size) as Size, sum(GEX) as GEX,
				cast(sum(GEX)*100.0/sum(sum(GEX)) over (partition by ASXCode, MoneyType, ObservationDate) as decimal(10, 2)) as AggPerc
			from #TempMoneyTypeByExpiryDate
			where ObservationDate >= dateadd(day, -10, getdate())
			and MoneyType = 'Smart'
			and BuySellIndicator in ('B', 'S')
			group by ASXCode, MoneyType, ObservationDate, BuySellIndicator, PorC
		) as y
		on x.ObservationDate = y.ObservationDate
		and x.CapitalType = y.CapitalType
		and x.ASXCode = y.ASXCode
		order by x.ObservationDate, x.CapitalType

		delete a
		from Transform.SmartDumbCapitalTypeRatio as a
		inner join #TempSmartDumbCapitalTypeRatio as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		insert into [Transform].[SmartDumbCapitalTypeRatio]
		(
			ASXCode,
			[ObservationDate],
			[CapitalType],
			[DumbGEX],
			[DumbAggPerc],
			[SmartGEX],
			[SmartAggPerc],
			[SmartDumbAggPercRatio],
			CreateDate
		)
		select
			ASXCode,
			[ObservationDate],
			[CapitalType],
			[DumbGEX],
			[DumbAggPerc],
			[SmartGEX],
			[SmartAggPerc],
			[SmartDumbAggPercRatio],
			getdate() as CreateDate
		from #TempSmartDumbCapitalTypeRatio

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_RefreshTransformBrokerReportList failed'
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