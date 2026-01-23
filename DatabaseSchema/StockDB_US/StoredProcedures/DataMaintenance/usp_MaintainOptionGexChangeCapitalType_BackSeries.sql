-- Stored procedure: [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType_BackSeries]






CREATE PROCEDURE [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType_BackSeries]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintPrevNumDay as int = 2
AS
/******************************************************************************
File: usp_MaintainOptionGexChangeCapitalType_BackSeries.sql
Stored Procedure Name: usp_MaintainOptionGexChangeCapitalType_BackSeries
Overview
-----------------
usp_MaintainOptionGexChangeCapitalType_BackSeries

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainOptionGexChangeCapitalType_BackSeries'
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
		declare @dtObservationDate as date = '2024-12-01' --Common.DateAddBusinessDay(-1*@pintPrevNumDay, getdate()) 
		--declare @dtObservationDateMinusN as date = Common.DateAddBusinessDay(-1*2, @dtObservationDate) 
		declare @dtObservationEndDate as date = '2025-01-10' 

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_V2') is not null
			drop table #TempOptionDelayedQuote_V2

		select *
		into #TempOptionDelayedQuote_V2
		from [StockData].[v_OptionDelayedQuote_V2_Include_Archive]
		where ObservationDate >= @dtObservationDate
		and ObservationDate <= @dtObservationEndDate
		--and ASXCode = 'TSLA.US'

		--declare @dtObservationDate as date = '2023-09-18'
		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_All_V2') is not null
			drop table #TempOptionDelayedQuote_All_V2

		select * 
		into #TempOptionDelayedQuote_All_V2
		from (
			select
				*,
				lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
				lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
				lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma
			from #TempOptionDelayedQuote_V2
		) as x
		where ObservationDate >= @dtObservationDate
		and ObservationDate <= @dtObservationEndDate

		--create index idx_transformoptiondelayquoteallv2_asxcodeobdate on Transform.v_OptionDelayedQuote_All_V2(ASXCode, ObservationDate)		

		if object_id(N'Tempdb.dbo.#TempOptionGEXChange') is not null
			drop table #TempOptionGEXChange
			
		select y.*, x.[Close], x.VWAP
		into #TempOptionGEXChange
		from StockData.v_PriceHistory as x
		right join
		(
			select 
				ObservationDate, ASXCode, 
				case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
					 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
					 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
				     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
				end as CapitalType, 
				cast(sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*(OpenInterest - Prev1OpenInterest)) as int) as GEXDelta 
			from #TempOptionDelayedQuote_All_V2
			where 1 = 1 
			--and ASXCode = 'SPXW.US'
			and ExpiryDate < dateadd(day, 120, ObservationDate)
			--and ObservationDate = '2023-09-12'
			group by 
				ObservationDate, 
				ASXCode, 
				case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
					 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
					 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
				     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
				end
			--order by 
			--	ObservationDate, 
			--	ASXCode, 
			--	case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
			--		 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
			--		 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
			--	     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
			--	end
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate	

		--select ASXCode, ObservationDate, count(*) 
		--from #TempOptionGEXChange
		--group by ASXCode, ObservationDate 
		--order by ObservationDate desc
		
		delete a
		from Transform.OptionGEXChangeCapitalType as a
		inner join 
		(
			select distinct ObservationDate, ASXCode
			from #TempOptionGEXChange
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		insert into Transform.OptionGEXChangeCapitalType
		(
			[ObservationDate],
			[ASXCode],
			[GEXDelta],
			[CapitalType],
			[Close],
			[VWAP]
		)
		select 
			[ObservationDate],
			[ASXCode],
			[GEXDelta],
			[CapitalType],
			[Close],
			[VWAP]		
		from #TempOptionGEXChange

		--declare @dtObservationDate as date = '2019-01-01' --Common.DateAddBusinessDay(-1*@pintPrevNumDay, getdate()) 
		--declare @dtObservationDateMinusN as date = Common.DateAddBusinessDay(-1*2, @dtObservationDate) 
		--declare @dtObservationEndDate as date = '2023-09-25' 

		if object_id(N'Tempdb.dbo.#TempPC') is not null
			drop table #TempPC
		
		select *
		into #TempPC
		from (
			select 
				ASXCode, 
				ObservationDate,
				PorC,
				case when PorC = 'C' then 1 else -1 end*cast(sum(a.Gamma*a.OpenInterest*100) as bigint) as Delta
			from [StockData].[v_OptionDelayedQuote_V2_Include_Archive] as a
			where 1 = 1
			group by 
				ASXCode, 
				ObservationDate,
				PorC
		) as x
		where 1 = 1 
		and ObservationDate >= @dtObservationDate
		and ObservationDate <= @dtObservationEndDate
		--and ASXCode = 'SPXW.US'
		order by ObservationDate desc

		delete a
		from Transform.OptionGEXByPutCall as a
		inner join #TempPC as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into Transform.OptionGEXByPutCall
		select * from #TempPC

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
