-- Stored procedure: [DataMaintenance].[usp_OptionLastHourAction]





CREATE PROCEDURE [DataMaintenance].[usp_OptionLastHourAction]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_MaintainStockData.sql
Stored Procedure Name: usp_MaintainStockData
Overview
-----------------
usp_MaintainStockData

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
Date:		2017-02-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_OptionLastHourAction'
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
		--declare @pintPrevNumDay as int = 60
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
		and a.ASXCode in ('SPXW.US')

		declare @dtObservationDate as date 
		select @dtObservationDate = max(ObservationDate)
		from StockData.v_OptionTrade

		declare @decClose as decimal(20, 4)
		select @decClose = [Close]
		from StockData.v_PriceHistory
		where ASXCode = 'SPXW.US'
		and ObservationDate = (select max(ObservationDate) from StockData.v_PriceHistory where ASXCode = 'SPXW.US')

		--select @dtObservationDate;
		--select @decClose
		if object_id(N'Tempdb.dbo.#TempOptionLastHourAction') is not null
			drop table #TempOptionLastHourAction

		declare @dtESTTimeNow as datetime
		select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')
		declare @dtStartTime as time
		select @dtStartTime = case when cast(@dtESTTimeNow as time) > '17:20:00' then '15:00:00' else cast(dateadd(minute, -240, @dtESTTimeNow) as time) end
		print @dtStartTime 

		select Underlying, @dtObservationDate as ObservationDate, CapitalType, Strike, cast(sum(x.Gamma) as int) as Gamma
		into #TempOptionLastHourAction
		from
		(
			select 
				case when a.PorC = 'C' and LongShortIndicator = 'Long' then 'BC'
					 when a.PorC = 'C' and LongShortIndicator = 'Short' then 'SC'
					 when a.PorC = 'P' and LongShortIndicator = 'Long' then 'SP'
					 when a.PorC = 'P' and LongShortIndicator = 'Short' then 'BP'
					 else 'UK'
				end CapitalType, 
				a.Strike,  
				sum(b.Gamma*100*a.Size) as Gamma,
				Underlying

			from StockData.v_OptionTrade as a with(nolock)
			inner join #TempOptionDelayedQuote as b
			on a.OptionSymbol = b.OptionSymbol
			where 1 = 1 
			--and OptionSymbol = 'SPXW231113P04400000'
			and a.ObservationDate = @dtObservationDate
			and cast(SaleTime as time) > @dtStartTime
			and Size < 50
			and Underlying in ('SPXW')
			and a.Strike between cast(@decClose as int) - 70 and cast(@decClose as int) + 70
			--and a.Strike = 4400
			group by a.Underlying, a.Strike, a.ExpiryDate,
			case when a.PorC = 'C' and LongShortIndicator = 'Long' then 'BC'
					 when a.PorC = 'C' and LongShortIndicator = 'Short' then 'SC'
					 when a.PorC = 'P' and LongShortIndicator = 'Long' then 'SP'
					 when a.PorC = 'P' and LongShortIndicator = 'Short' then 'BP'
					 else 'UK'
				end
		) as x
		group by Underlying, CapitalType, Strike
		order by Strike

		delete a
		from Transform.OptionLastHourAction as a
		inner join #TempOptionLastHourAction as b
		on a.ObservationDate = b.ObservationDate
		and a.Underlying  = b.Underlying

		insert into Transform.OptionLastHourAction
		select *
		from #TempOptionLastHourAction

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
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
