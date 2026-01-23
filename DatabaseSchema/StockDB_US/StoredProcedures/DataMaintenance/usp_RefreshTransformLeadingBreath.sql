-- Stored procedure: [DataMaintenance].[usp_RefreshTransformLeadingBreath]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformLeadingBreath]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformLeadingBreath.sql
Stored Procedure Name: usp_RefreshTransformLeadingBreath
Overview
-----------------
usp_RefreshTransformLeadingBreath

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
Date:		2023-05-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformLeadingBreath'
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
		
		if object_id(N'Tempdb.dbo.#TempBase') is not null
			drop table #TempBase

		select 
			a.ObservationDate,
			a.ASXCode,
			a.TodayChange,
			100 as TodayStart,
			100*(1+0.01*TodayChange) as TodayEnd
		into #TempBase
		from StockData.v_PriceHistory as a
		inner join [dbo].[Component Stocks - SPX500] as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate >= '2018-01-01'

		if object_id(N'Tempdb.dbo.#TempBaseCumulative') is not null
			drop table #TempBaseCumulative
		
		select 
			x.ObservationDate, x.TodayValueChange, x.AvgTodayChange as TodayAverageChange, y.TodayChange, row_number() over (partition by 1 order by x.ObservationDate asc) as RowNumber, 
			cast(null as decimal(20, 4)) as BreathClosePrice,
			cast(null as decimal(20, 4)) as SPXClosePrice
		into #TempBaseCumulative
		from
		(
			select ObservationDate, sum(TodayStart) as TodayStart, sum(TodayEnd) as TodayEnd, (sum(TodayEnd)*1.0/sum(TodayStart) - 1)*100.0 as TodayValueChange, avg(TodayChange) as AvgTodayChange
			from #TempBase
			group by ObservationDate
		) as x
		left join StockDB.StockData.v_PriceHistory as y
		on x.ObservationDate = y.ObservationDate
		and y.ASXCode = 'SPX'
		order by ObservationDate desc;

		update a
		set BreathClosePrice = 100,
			SPXClosePrice =  100
		from #TempBaseCumulative as a
		where RowNumber = 1

		declare @intNum as int = 1

		while @intNum > 0
		begin
			update a
			set a.BreathClosePrice = b.BreathClosePrice*0.01*a.TodayValueChange + b.BreathClosePrice,
				a.SPXClosePrice = b.SPXClosePrice*0.01*a.TodayChange + b.SPXClosePrice
			from #TempBaseCumulative as a
			inner join #TempBaseCumulative as b
			on a.RowNumber = b.RowNumber + 1
			where a.BreathClosePrice is null
			
			select @intNum = @@ROWCOUNT
		end

		delete a
		from Transform.LeadingBreath as a
		inner join #TempBaseCumulative as b
		on a.ObservationDate = b.ObservationDate

		insert into Transform.LeadingBreath
		(
		   [ObservationDate]
		  ,[TodayValueChange]
		  ,TodayAverageChange
		  ,[TodayChange]
		  ,[RowNumber]
		  ,[BreathClosePrice]
		  ,[SPXClosePrice]
		)
		select 
		   [ObservationDate]
		  ,[TodayValueChange]
		  ,TodayAverageChange
		  ,[TodayChange]
		  ,[RowNumber]
		  ,[BreathClosePrice]
		  ,[SPXClosePrice]
		from #TempBaseCumulative

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
