-- Stored procedure: [Report].[usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ]


CREATE PROCEDURE [Report].[usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ.sql
Stored Procedure Name: usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ
Overview
-----------------
usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ

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
Date:		2018-02-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ'
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
		--declare @pintCountNumDaysBack as int = 30

		if object_id(N'Tempdb.dbo.#TempTransaction') is not null
			drop table #TempTransaction

		select 
			identity(int, 1, 1) as UniqueKey,
			cast(null as decimal(20, 4)) as CumulativeGain,
			--case when SwingIndicator = 'Swing Up' then a.TomorrowOpenToCloseChange 
			--		when SwingIndicator = 'Swing Down' then b.TomorrowOpenToCloseChange
			--end as TomorrowOpenToCloseChange, 
			case when SwingIndicator = 'Swing Up' then a.TomorrowChange
					when SwingIndicator = 'Swing Down' then b.TomorrowChange
			end as TomorrowOpenToCloseChange, 
			case when SwingIndicator = 'Swing Up' then a.TomorrowChange
					when SwingIndicator = 'Swing Down' then b.TomorrowChange
			end as TomorrowChange,
			c.SwingIndicator,
			a.ObservationDate,
			case when SwingIndicator = 'Swing Up' then a.ASXCode
					when SwingIndicator = 'Swing Down' then b.ASXCode
			end as ASXCode,
			case when SwingIndicator = 'Swing Up' then a.[Close]
					when SwingIndicator = 'Swing Down' then b.[Close]
			end as [Close],
			case when SwingIndicator = 'Swing Up' then a.[Open]
					when SwingIndicator = 'Swing Down' then b.[Open]
			end as [Open]
		into #TempTransaction
		from [StockData].[v_PriceHistoryAfterMarket] as a
		inner join [StockData].[v_PriceHistoryAfterMarket] as b
		on a.ObservationDate = b.ObservationDate
		inner join
		(
			select SwingIndicator, ObservationDate	
			from Transform.v_SPX_SPXW_OptionMoneyFlow
			where SwingIndicator in ('Swing Up', 'Swing Down')
		) as c
		on a.ObservationDate = c.ObservationDate
		where a.ASXCode = 'TQQQ.US'
		and b.ASXCode = 'SQQQ.US'
		--and a.ObservationDate > '2023-01-01'
		order by a.ObservationDate asc;

		update a
		set CumulativeGain = 100 + 100*0.01*a.TomorrowOpenToCloseChange
		from #TempTransaction as a
		where a.UniqueKey = 1

		declare @intNum as int = 1

		while @intNum > 0
		begin
			update a
			set a.CumulativeGain = b.CumulativeGain + b.CumulativeGain*0.01*a.TomorrowOpenToCloseChange
			from #TempTransaction as a
			inner join #TempTransaction as b
			on a.UniqueKey = b.UniqueKey + 1
			and a.CumulativeGain is null
			and b.CumulativeGain is not null
			and a.TomorrowOpenToCloseChange is not null
	
			select @intNum = @@ROWCOUNT
		end

		delete a
		from #TempTransaction as a
		where TomorrowOpenToCloseChange is null

		delete a
		from [Transform].[StrategySimulator] as a
		inner join #TempTransaction as b
		on a.Underlying = 'NASDAQ'
		and a.StrategyID = (select StrategyID from LookupRef.Strategy where StrategyName = 'Option Capital Flow - SPXW')
		and a.ObservationDate = b.ObservationDate

		insert into [Transform].[StrategySimulator]
		(
		   [UniqueKey]
		  ,StrategyID
		  ,[Underlying]
		  ,[CumulativeGain]
		  ,[TomorrowOpenToCloseChange]
		  ,[TomorrowChange]
		  ,[SwingIndicator]
		  ,[ObservationDate]
		  ,[ASXCode]
		  ,[Close]
		  ,[Open]
		  ,[CreateDate]
		)
		select
		   [UniqueKey]
		  ,(select StrategyID from LookupRef.Strategy where StrategyName = 'Option Capital Flow - SPXW') as StrategyID
		  ,'NASDAQ' as [Underlying]
		  ,[CumulativeGain]
		  ,[TomorrowOpenToCloseChange]
		  ,[TomorrowChange]
		  ,[SwingIndicator]
		  ,[ObservationDate]
		  ,[ASXCode]
		  ,[Close]
		  ,[Open]
		  ,getdate() as [CreateDate]
		from #TempTransaction
		order by ObservationDate		
		

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
