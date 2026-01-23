-- Stored procedure: [Transform].[usp_RefreshPriceHistoryWeekly]


CREATE PROCEDURE [Transform].[usp_RefreshPriceHistoryWeekly]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshPriceHistoryWeekly.sql
Stored Procedure Name: usp_RefreshPriceHistoryWeekly
Overview
-----------------
usp_RefreshPriceHistoryWeekly

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
Date:		2019-07-25
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPriceHistoryWeekly'
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
		if object_id(N'Working.PriceHistory') is not null
			drop table Working.PriceHistory

		select a.*, b.[Year], b.WeekOfYear, b.[Weekday]
		into Working.PriceHistory
		from [Transform].[v_PriceHistory] as a
		inner join LookupRef.DimDate as b
		on a.ObservationDate = b.[Date]
		where 
		(
			a.Volume > 0
			or
			a.ASXCode in ('XAO.AX', 'XJO.AX', 'XSO.AX', 'XEC.AX')
		)

		if object_id(N'Working.PriceHistoryWeekly') is not null
			drop table Working.PriceHistoryWeekly

		select 
			ASXCode, 
			[Year], 
			WeekOfYear, 
			cast(null as decimal(20, 4)) as [Open],
			cast(null as decimal(20, 4)) as [Close],
			min(low) as Low,
			max(High) as High,
			sum(Volume) as Volume,
			min(ObservationDate) as WeekOpenDate,
			max(ObservationDate) as WeekCloseDate,
			count(ASXCode) as NumTradeDay
		into Working.PriceHistoryWeekly
		from Working.PriceHistory
		--where ObservationDate <= '2019-09-06'
		group by ASXCode, [Year], WeekOfYear

		update a
		set a.[Open] = b.[Open]
		from Working.PriceHistoryWeekly as a
		inner join Working.PriceHistory as b
		on a.ASXCode = b.ASXCode
		and a.WeekOpenDate = b.ObservationDate

		update a
		set a.[Close] = b.[Close]
		from Working.PriceHistoryWeekly as a
		inner join Working.PriceHistory as b
		on a.ASXCode = b.ASXCode
		and a.WeekCloseDate = b.ObservationDate

		delete a
		from [StockData].[PriceHistoryWeekly] as a
		where datediff(day, WeekOpenDate, getdate()) < 30

		insert into [StockData].[PriceHistoryWeekly]
		(
			[ASXCode],
			[Year],
			[WeekOfYear],
			[Open],
			[Close],
			[Low],
			[High],
			[Volume],
			VolumeRaw,
			[WeekOpenDate],
			[WeekCloseDate],
			NumTradeDay
		)
		select
			[ASXCode],
			[Year],
			[WeekOfYear],
			[Open],
			[Close],
			[Low],
			[High],
			cast(Volume*5.0/NumTradeDay as bigint) as [Volume],
			Volume as VolumeRaw,
			[WeekOpenDate],
			[WeekCloseDate],
			NumTradeDay
		from Working.PriceHistoryWeekly
		where datediff(day, WeekOpenDate, getdate()) < 30
		
		delete m
		from [StockData].[PriceHistoryWeekly] as m
		inner join
		(
			select x.ASXCode, x.WeekOpenDate
			from
			(
				select 
					*,
					lead(WeekOpenDate) over (partition by ASXCode order by WeekOpenDate) as NextWeekOpenDate
				from [StockData].[PriceHistoryWeekly] as a
			) as x
			where datediff(day, WeekOpenDate, NextWeekOpenDate) > 75
		) as n
		on m.ASXCode = n.ASXCode
		and m.WeekOpenDate <= n.WeekOpenDate
		
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
