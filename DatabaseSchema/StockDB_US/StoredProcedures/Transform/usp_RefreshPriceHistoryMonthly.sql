-- Stored procedure: [Transform].[usp_RefreshPriceHistoryMonthly]





CREATE PROCEDURE [Transform].[usp_RefreshPriceHistoryMonthly]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshPriceHistoryMonthly.sql
Stored Procedure Name: usp_RefreshPriceHistoryMonthly
Overview
-----------------
usp_RefreshPriceHistoryMonthly

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
Date:		2019-08-03
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPriceHistoryMonthly'
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
		if object_id(N'Working.PriceHistory2') is not null
			drop table Working.PriceHistory2
			
		select a.*, b.[Year], b.[Month], b.[Day]
		into Working.PriceHistory2
		from StockData.PriceHistory as a
		inner join LookupRef.DimDate as b
		on a.ObservationDate = b.[Date]
		where 
		(
			a.Volume > 0
			or
			a.ASXCode in ('XAO.AX', 'XJO.AX', 'XSO.AX', 'XEC.AX')
		)

		if object_id(N'Working.PriceHistoryMonthly') is not null
			drop table Working.PriceHistoryMonthly

		select 
			ASXCode, 
			[Year], 
			[Month], 
			cast(null as decimal(20, 4)) as [Open],
			cast(null as decimal(20, 4)) as [Close],
			min(low) as Low,
			max(High) as High,
			sum(Volume) as Volume,
			min(ObservationDate) as MonthOpenDate,
			max(ObservationDate) as MonthCloseDate,
			count(ASXCode) as NumTradeDay
		into Working.PriceHistoryMonthly
		from Working.PriceHistory2
		--where ObservationDate <= '2019-09-06'
		group by ASXCode, [Year], [Month]

		update a
		set a.[Open] = b.[Open]
		from Working.PriceHistoryMonthly as a
		inner join Working.PriceHistory2 as b
		on a.ASXCode = b.ASXCode
		and a.MonthOpenDate = b.ObservationDate

		update a
		set a.[Close] = b.[Close]
		from Working.PriceHistoryMonthly as a
		inner join Working.PriceHistory2 as b
		on a.ASXCode = b.ASXCode
		and a.MonthCloseDate = b.ObservationDate

		truncate table [StockData].[PriceHistoryMonthly]

		insert into [StockData].[PriceHistoryMonthly]
		(
			[ASXCode],
			[Year],
			[MonthOfYear],
			[Open],
			[Close],
			[Low],
			[High],
			[Volume],
			VolumeRaw,
			[MonthOpenDate],
			[MonthCloseDate],
			NumTradeDay
		)
		select
			[ASXCode],
			[Year],
			[Month],
			[Open],
			[Close],
			[Low],
			[High],
			cast(Volume*22.0/NumTradeDay as bigint) as [Volume],
			Volume as VolumeRaw,
			[MonthOpenDate],
			[MonthCloseDate],
			NumTradeDay
		from Working.PriceHistoryMonthly

		delete m
		from [StockData].[PriceHistoryMonthly] as m
		inner join
		(
			select x.ASXCode, x.MonthOpenDate
			from
			(
				select 
					*,
					lead(MonthOpenDate) over (partition by ASXCode order by MonthOpenDate) as NextMonthOpenDate
				from [StockData].[PriceHistoryMonthly] as a
			) as x
			where datediff(day, MonthOpenDate, NextMonthOpenDate) > 75
		) as n
		on m.ASXCode = n.ASXCode
		and m.MonthOpenDate <= n.MonthOpenDate
		
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
